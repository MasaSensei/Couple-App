<?php

namespace Tests\Feature\Billing;

use App\Models\Couple;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Services\Billing\StorageQuotaService;
use App\Services\Billing\SubscriptionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class StorageQuotaTest extends TestCase
{
    use BillingHelpers, RefreshDatabase;

    private const GIB = 1024 ** 3;

    private User $alice;

    private User $bob;

    private Couple $couple;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
        $this->seedPlans();
        [$this->alice, $this->bob, $this->couple] = $this->makeCouple();
    }

    private function usage(): array
    {
        return app(StorageQuotaService::class)->usage($this->couple);
    }

    private function requestUpload(User $user, int $bytes = 1000)
    {
        $memory = Memory::firstOrCreate(['couple_id' => $this->couple->id], Memory::factory()->raw(['couple_id' => $this->couple->id, 'created_by' => $user->id]));

        return $this->actingAs($user)->postJson("/api/v1/memories/{$memory->id}/photos/upload", [
            'mime_type' => 'application/octet-stream',
            'file_size' => $bytes - 28,
            'encrypted_size' => $bytes,
        ]);
    }

    public function test_usage_counts_ciphertext_of_live_photos_once(): void
    {
        $this->photo($this->couple, $this->alice, 100);                                  // verified, backed up
        $this->photo($this->couple, $this->bob, 500, ['backup_status' => 'pending']);     // verified, backup not yet
        $this->photo($this->couple, $this->alice, 200, ['deleted_at' => now()]);          // in trash
        $this->photo($this->couple, $this->alice, 300, ['status' => 'pending']);          // upload in progress
        $this->photo($this->couple, $this->alice, 400, ['status' => 'failed']);           // never stored
        $this->photo($this->couple, $this->alice, 999, ['status' => 'pending', 'created_at' => now()->subDays(2)]); // abandoned

        // Another couple's photos never count here.
        [$other] = $this->makeCouple();
        $this->photo(Couple::latest('id')->first(), $other, 7777);

        $usage = $this->usage();

        // A backed-up photo (primary + backup replica) counts its 100 bytes once.
        $this->assertSame(600, $usage['used_bytes']);
        $this->assertSame(200, $usage['trash_bytes']);
        $this->assertSame(300, $usage['reserved_bytes']);
        $this->assertSame(2, $usage['photo_count']);
        $this->assertSame(self::GIB - 600, $usage['remaining_bytes']);

        $this->actingAs($this->bob)->getJson('/api/v1/couple/storage')
            ->assertOk()->assertJsonPath('data.storage.used_bytes', 600);
    }

    public function test_upload_is_refused_when_full_but_everything_else_keeps_working(): void
    {
        $existing = $this->photo($this->couple, $this->alice, self::GIB - 500);
        Storage::disk('photos_primary')->put($existing->storage_key, 'CIPHERTEXT');

        $this->requestUpload($this->alice, 1000)
            ->assertStatus(422)
            ->assertJsonPath('data.code', 'storage_quota_exceeded')
            ->assertJsonPath('data.storage.limit_bytes', self::GIB);
        $this->assertSame(1, MemoryPhoto::count(), 'nothing was reserved');

        // Viewing, downloading and deleting still work.
        $this->actingAs($this->bob)->getJson("/api/v1/memories/{$existing->memory_id}/photos")->assertOk()->assertJsonCount(1, 'data.photos');
        $this->actingAs($this->bob)->get("/api/v1/memory-photos/{$existing->id}/content")->assertOk();
        $this->actingAs($this->bob)->getJson('/api/v1/memories')->assertOk();
        $this->actingAs($this->bob)->deleteJson("/api/v1/memory-photos/{$existing->id}")->assertOk();

        // Deleting frees space immediately.
        $this->requestUpload($this->alice, 1000)->assertCreated();

        // ...and restoring needs that space back.
        $this->photo($this->couple, $this->alice, self::GIB - 2000);
        $this->actingAs($this->alice)->postJson("/api/v1/memory-photos/{$existing->id}/restore")
            ->assertStatus(422)->assertJsonPath('data.code', 'storage_quota_exceeded');
        $this->assertTrue($existing->refresh()->trashed(), 'stays safely in the trash');
    }

    public function test_in_progress_uploads_reserve_space_so_partners_cannot_overfill_together(): void
    {
        $this->photo($this->couple, $this->alice, self::GIB - 1500);

        $this->requestUpload($this->alice, 1000)->assertCreated();
        $this->requestUpload($this->bob, 1000)->assertStatus(422)->assertJsonPath('data.code', 'storage_quota_exceeded');
    }

    public function test_completion_rechecks_the_quota_with_the_declared_ciphertext_size(): void
    {
        $pending = $this->photo($this->couple, $this->alice, 1000, ['status' => 'uploading']);
        // Space taken meanwhile by a photo that is already verified (e.g. restored).
        $this->photo($this->couple, $this->bob, self::GIB - 500);

        $this->actingAs($this->alice)->postJson("/api/v1/memory-photos/{$pending->id}/complete")
            ->assertStatus(422)->assertJsonPath('data.code', 'storage_quota_exceeded');

        $this->assertSame('failed', $pending->refresh()->status);
        $this->assertSame(self::GIB - 500, $this->usage()['used_bytes'], 'the refused upload never counts');
    }

    public function test_paid_plan_raises_the_quota_and_expiry_never_deletes_anything(): void
    {
        $this->buy($this->alice)->assertOk();
        $this->assertSame(20 * self::GIB, $this->usage()['limit_bytes']);

        $photos = collect([3, 3])->map(fn ($gib) => $this->photo($this->couple, $this->alice, $gib * self::GIB));
        $this->requestUpload($this->bob)->assertCreated();

        // Subscription ends; the couple is now 5 GiB over the Free quota.
        $subscription = $this->liveSubscription($this->couple);
        $this->store()->cancel($subscription->provider_subscription_id);
        $this->webhook($subscription->provider_subscription_id, 'cancelled');
        $this->travelTo($subscription->current_period_end->copy()->addMinute());
        app(SubscriptionService::class)->sweep();

        $usage = $this->usage();
        $this->assertSame([self::GIB, true], [$usage['limit_bytes'], $usage['is_full']]);
        $this->assertSame(2, MemoryPhoto::whereIn('id', $photos->pluck('id'))->count(), 'no photo deleted');
        $this->actingAs($this->bob)->getJson("/api/v1/memories/{$photos[0]->memory_id}/photos")->assertOk()->assertJsonCount(2, 'data.photos');
        $this->requestUpload($this->bob)->assertStatus(422)->assertJsonPath('data.code', 'storage_quota_exceeded');
        $this->actingAs($this->bob)->deleteJson("/api/v1/memory-photos/{$photos[0]->id}")->assertOk();
    }
}
