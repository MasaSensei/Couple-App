<?php

namespace Tests\Feature\Storage;

use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\Couple;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use App\Services\Storage\PhotoReconciliationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PhotoReconciliationTest extends TestCase
{
    use RefreshDatabase;

    private Memory $memory;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
        Queue::fake();

        $user = User::factory()->create();
        $this->memory = Memory::factory()->create(['couple_id' => Couple::factory()->create()->id, 'created_by' => $user->id]);
    }

    private function photo(array $attributes = [], bool $primary = true, bool $backup = true): MemoryPhoto
    {
        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $this->memory->id,
            'storage_key' => 'couples/1/memories/1/photos/'.fake()->uuid(),
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'checksum' => hash('sha256', 'c'),
            'status' => 'verified',
            'backup_status' => 'verified',
            ...$attributes,
        ]);
        $photo->save();

        $primary && Storage::disk('photos_primary')->put($photo->storage_key, 'c');
        $backup && Storage::disk('photos_backup')->put($photo->storage_key, 'c');

        return $photo;
    }

    public function test_consistent_state_is_clean(): void
    {
        $this->photo();

        $this->artisan('photos:reconcile')->assertSuccessful();

        Queue::assertNothingPushed();
        $this->assertSame('succeeded', PhotoStorageAudit::where('action', 'reconcile')->value('result'));
    }

    public function test_detects_every_inconsistency_and_deletes_nothing(): void
    {
        $missingPrimary = $this->photo(primary: false);
        $missingBackup = $this->photo(backup: false);
        $unfinished = $this->photo(['status' => 'pending', 'backup_status' => null], primary: false, backup: false);
        $unfinished->forceFill(['created_at' => now()->subDays(2)])->save();
        $stale = $this->photo(['backup_status' => 'pending'], backup: false);
        MemoryPhoto::whereKey($stale->id)->update(['updated_at' => now()->subHours(2)]);
        // Object newer than a restored DB: no row.
        Storage::disk('photos_primary')->put('couples/1/memories/1/photos/orphan', 'x');
        Storage::disk('photos_backup')->put('couples/1/memories/1/photos/orphan', 'x');
        // Purged primary is expected to be absent.
        $this->photo(['primary_purged_at' => now(), 'deleted_at' => now()->subDays(40)], primary: false);

        $this->artisan('photos:reconcile')->assertFailed();

        $report = app(PhotoReconciliationService::class)->run(queueChecks: false);
        $this->assertSame([$missingPrimary->id], $report['missing_primary']);
        $this->assertSame([$missingBackup->id], $report['missing_backup']);
        $this->assertSame([$unfinished->id], $report['unfinished_uploads']);
        $this->assertSame([$stale->id], $report['stale_backups']);
        $this->assertSame(['couples/1/memories/1/photos/orphan'], $report['orphan_primary']);
        $this->assertSame(['couples/1/memories/1/photos/orphan'], $report['orphan_backup']);

        // Report-only: orphans and rows are all still there; checks queued for missing copies.
        Storage::disk('photos_primary')->assertExists('couples/1/memories/1/photos/orphan');
        $this->assertSame(5, MemoryPhoto::withTrashed()->count());
        Queue::assertPushed(VerifyMemoryPhotoIntegrity::class, 2);
    }
}
