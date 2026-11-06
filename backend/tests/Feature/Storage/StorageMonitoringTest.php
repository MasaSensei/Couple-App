<?php

namespace Tests\Feature\Storage;

use App\Jobs\BackupMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Models\Couple;
use App\Models\DatabaseBackup;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use App\Services\Storage\StorageHealthService;
use App\Services\Storage\StorageOperatorActions;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Mockery;
use Tests\TestCase;

class StorageMonitoringTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private Memory $memory;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
        Queue::fake();

        $this->admin = User::factory()->create(['is_admin' => true]);
        $this->memory = Memory::factory()->create([
            'couple_id' => Couple::factory()->create()->id,
            'created_by' => User::factory()->create()->id,
        ]);
    }

    private function photo(array $attributes = []): MemoryPhoto
    {
        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $this->memory->id,
            'storage_key' => 'couples/1/memories/1/photos/'.fake()->uuid(),
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'encrypted_size' => 100,
            'checksum' => str_repeat('a', 64),
            'encryption_version' => '1', 'key_id' => 'key-SECRET-ID', 'nonce' => 'NONCE-VALUE', 'mac' => 'MAC-VALUE',
            'status' => 'verified',
            'backup_status' => 'verified',
            ...$attributes,
        ]);
        $photo->save();

        return $photo;
    }

    public function test_metrics_count_each_protection_state(): void
    {
        $this->photo();
        $this->photo();
        $this->photo(['backup_status' => 'pending']);
        $this->photo(['backup_status' => 'failed']);
        $this->photo(['primary_integrity' => 'mismatch', 'repair_status' => 'pending']);
        $this->photo(['primary_integrity' => 'mismatch', 'backup_integrity' => 'mismatch', 'repair_status' => 'failed']);
        $this->photo(['deleted_at' => now()]);

        $m = app(StorageHealthService::class)->metrics();

        $this->assertSame(6, $m['photos_total']);
        $this->assertSame(2, $m['protected']);
        $this->assertSame(1, $m['backup_pending']);
        $this->assertSame(2, $m['degraded']);
        $this->assertSame(1, $m['restoring']);
        $this->assertSame(2, $m['integrity_mismatch']);
        $this->assertSame(1, $m['needs_operator']);
        $this->assertSame(1, $m['in_trash']);
        $this->assertSame(400, $m['backup_bytes']);
    }

    public function test_alerts_cover_backup_integrity_repair_and_database_backup(): void
    {
        $stale = $this->photo(['backup_status' => 'pending']);
        MemoryPhoto::whereKey($stale->id)->update(['updated_at' => now()->subHours(2)]);
        $this->photo(['primary_integrity' => 'mismatch', 'repair_status' => 'failed']);

        $codes = collect(app(StorageHealthService::class)->alerts())->pluck('code')->all();

        foreach (['backup_pending', 'integrity_mismatch', 'repair_failed', 'degraded', 'db_backup_missing'] as $code) {
            $this->assertContains($code, $codes);
        }

        DatabaseBackup::create(['status' => 'succeeded', 'started_at' => now()->subDays(2), 'finished_at' => now()->subDays(2)]);
        $codes = collect(app(StorageHealthService::class)->alerts())->pluck('code')->all();
        $this->assertContains('db_backup_stale', $codes);
        $this->assertContains('db_restore_untested', $codes);
    }

    public function test_unreachable_store_raises_an_alert(): void
    {
        $broken = Mockery::mock(\App\Services\Storage\PhotoStorage::class);
        $broken->shouldReceive('listKeys')->andThrow(new \RuntimeException('Connection refused.'));
        $this->app->instance('photos.backup', $broken);

        $codes = collect(app(StorageHealthService::class)->alerts())->pluck('code')->all();

        $this->assertContains('backup_unreachable', $codes);
        $this->assertNotContains('primary_unreachable', $codes);
    }

    public function test_alert_command_logs_once_then_resolves(): void
    {
        $this->photo(['primary_integrity' => 'mismatch', 'repair_status' => 'failed']);

        $channel = Mockery::mock();
        $channel->shouldReceive('critical')->withArgs(fn ($message) => str_contains($message, 'need an operator'))->once();
        $channel->shouldReceive('critical');
        $channel->shouldReceive('warning');
        $channel->shouldReceive('notice')->withArgs(fn ($message) => $message === 'Resolved: repair_failed')->once();
        $channel->shouldReceive('notice'); // other alerts clearing at the same time
        Log::shouldReceive('channel')->with('alerts')->andReturn($channel);

        $this->artisan('storage:alerts')->assertFailed();
        $this->artisan('storage:alerts')->assertFailed(); // still active: not re-sent

        MemoryPhoto::query()->update(['repair_status' => null, 'primary_integrity' => 'ok']);
        $this->artisan('storage:alerts');
    }

    public function test_operator_actions_are_queued_and_audited(): void
    {
        $failed = $this->photo(['backup_status' => 'failed', 'backup_error' => 'boom']);
        $degraded = $this->photo(['primary_integrity' => 'missing', 'repair_status' => 'failed']);
        $actions = app(StorageOperatorActions::class);

        $actions->retryBackup($failed, $this->admin);
        $actions->verifyIntegrity($failed, $this->admin);
        $actions->requestRepair($degraded, $this->admin);

        $this->assertSame('pending', $failed->refresh()->backup_status);
        $this->assertSame('pending', $degraded->refresh()->repair_status);
        Queue::assertPushed(BackupMemoryPhoto::class);
        Queue::assertPushed(RepairMemoryPhoto::class, fn ($job) => $job->actor === "user:{$this->admin->id}");
        $this->assertSame(
            ['admin_retry_backup', 'admin_verify', 'admin_repair'],
            PhotoStorageAudit::where('actor', "user:{$this->admin->id}")->orderBy('id')->pluck('action')->all(),
        );
    }

    public function test_non_admin_cannot_run_operator_actions(): void
    {
        $this->expectException(AuthorizationException::class);

        app(StorageOperatorActions::class)->retryBackup($this->photo(['backup_status' => 'failed']), User::factory()->create());
    }

    public function test_admin_storage_pages_show_metadata_but_never_content_or_secrets(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->put($photo->storage_key, 'CIPHERTEXT-BYTES');

        foreach (['/admin/memory-photos', '/admin/database-backups', '/admin/storage-audits'] as $url) {
            $html = $this->actingAs($this->admin)->get($url)->assertOk()->getContent();

            $this->assertStringNotContainsString($photo->storage_key, $html);
            $this->assertStringNotContainsString('NONCE-VALUE', $html);
            $this->assertStringNotContainsString('MAC-VALUE', $html);
            $this->assertStringNotContainsString('CIPHERTEXT-BYTES', $html);
            $this->assertStringNotContainsString(config('filesystems.disks.photos_backup.secret') ?? 'no-secret-configured', $html);
        }

        // No view/download/edit page exists for photos.
        $this->actingAs($this->admin)->get("/admin/memory-photos/{$photo->id}")->assertNotFound();
        $this->actingAs($this->admin)->get("/admin/memory-photos/{$photo->id}/edit")->assertNotFound();
    }

    public function test_health_widget_renders_counts_without_secrets(): void
    {
        $this->photo();
        $this->photo(['backup_status' => 'pending']);
        $this->actingAs($this->admin);

        \Livewire\Livewire::test(\App\Filament\Widgets\StorageHealthOverview::class)
            ->assertOk()
            ->assertSee('Protected photos')
            ->assertSee('1 / 2')
            ->assertSee('Database backup')
            ->assertDontSee('NONCE-VALUE')
            ->assertDontSee('key-SECRET-ID');
    }

    public function test_non_admin_cannot_open_storage_pages(): void
    {
        $user = User::factory()->create(['is_admin' => false]);

        $this->actingAs($user)->get('/admin/memory-photos')->assertForbidden();
    }
}
