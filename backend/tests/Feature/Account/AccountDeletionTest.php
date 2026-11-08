<?php

namespace Tests\Feature\Account;

use App\Jobs\PurgeMemoryPhoto;
use App\Models\CoupleMember;
use App\Models\Date;
use App\Models\Memory;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\Feature\Billing\BillingHelpers;
use Tests\TestCase;

/** Account deletion & data export (docs/operations/account-deletion.md). */
class AccountDeletionTest extends TestCase
{
    use BillingHelpers, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
        Queue::fake();
        $this->seedPlans();
    }

    private function deleteAccount(User $user, string $password = 'password')
    {
        $token = $user->createToken('flutter-app')->plainTextToken;
        // Several users act in one test: never reuse the previously resolved user.
        $this->app['auth']->forgetGuards();

        return $this->withToken($token)->deleteJson('/api/v1/me', ['password' => $password]);
    }

    public function test_wrong_password_deletes_nothing(): void
    {
        [$alice] = $this->makeCouple();

        $this->deleteAccount($alice, 'not-my-password')->assertStatus(422)->assertJsonPath('data.errors.password.0', 'The password is incorrect.');

        $this->assertNotNull($alice->fresh());
    }

    public function test_partner_keeps_the_shared_space_and_authorship_becomes_anonymous(): void
    {
        [$alice, $bob, $couple] = $this->makeCouple();
        $photo = $this->photo($couple, $alice, 1000);
        $date = Date::factory()->create(['couple_id' => $couple->id, 'created_by' => $alice->id]);
        DB::table('date_comments')->insert(['date_id' => $date->id, 'user_id' => $alice->id, 'content' => 'mine', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('date_comments')->insert(['date_id' => $date->id, 'user_id' => $bob->id, 'content' => 'bob', 'created_at' => now(), 'updated_at' => now()]);
        $device = UserDevice::create(['user_id' => $alice->id, 'device_identifier' => 'a-phone', 'platform' => 'ios', 'public_key' => base64_encode(random_bytes(32))]);

        $this->deleteAccount($alice)->assertOk()->assertJsonPath('data.couple', 'kept_by_partner');

        $this->assertNull(User::find($alice->id));
        $this->assertSame(0, PersonalAccessToken::where('tokenable_id', $alice->id)->count());
        $this->assertNull(UserDevice::find($device->id));
        $this->assertSame([$bob->id], CoupleMember::where('couple_id', $couple->id)->pluck('user_id')->all());

        // Shared content stays, now without an author.
        $this->assertNull($photo->fresh()->uploaded_by);
        $this->assertNull($photo->fresh()->deleted_at);
        $this->assertNull(Memory::find($photo->memory_id)->created_by);
        $this->assertNull($date->fresh()->created_by);

        // Alice's own comments go; Bob's stay.
        $this->assertSame(['bob'], DB::table('date_comments')->pluck('content')->all());

        // Bob still sees everything through the API.
        $this->actingAs($bob)->getJson("/api/v1/dates/{$date->id}")->assertOk()->assertJsonPath('data.date.created_by', null);
    }

    public function test_last_member_dissolves_the_space_through_the_normal_trash_and_purge(): void
    {
        [$alice, $bob, $couple] = $this->makeCouple();
        $photo = $this->photo($couple, $alice, 1000);
        Date::factory()->create(['couple_id' => $couple->id, 'created_by' => $bob->id]);

        $this->deleteAccount($bob)->assertOk()->assertJsonPath('data.couple', 'kept_by_partner');
        $this->deleteAccount($alice)->assertOk()->assertJsonPath('data.couple', 'dissolved');

        $this->assertNotNull($photo->fresh()->deleted_at, 'Photo is in the trash, not hard-deleted.');
        $this->assertSame(0, Memory::where('couple_id', $couple->id)->count());
        $this->assertSame(0, Date::where('couple_id', $couple->id)->count());
        $this->assertDatabaseHas('photo_storage_audits', ['memory_photo_id' => $photo->id, 'action' => 'trash']);

        // The retention purge picks it up once trash retention has passed.
        $this->travel(config('photos.trash_retention_days') + 1)->days();
        $this->artisan('photos:purge')->assertSuccessful();
        Queue::assertPushed(PurgeMemoryPhoto::class);
    }

    public function test_last_member_with_a_renewing_store_subscription_must_cancel_first(): void
    {
        [$alice, $bob, $couple] = $this->makeCouple();
        Queue::fake();
        $this->buy($alice)->assertOk();
        $this->deleteAccount($bob)->assertOk();

        $this->deleteAccount($alice)->assertStatus(422)->assertJsonPath('success', false);
        $this->assertNotNull($alice->fresh());

        $this->actingAs($alice)->postJson('/api/v1/couple/subscription/cancel')->assertOk();
        $this->app['auth']->forgetGuards();
        $this->deleteAccount($alice->fresh())->assertOk();
    }

    public function test_user_without_a_couple_can_delete_their_account(): void
    {
        $user = User::factory()->create();

        $this->deleteAccount($user)->assertOk()->assertJsonPath('data.couple', 'none');
        $this->assertNull(User::find($user->id));
    }

    public function test_export_contains_the_users_data_and_no_secrets(): void
    {
        [$alice, $bob, $couple] = $this->makeCouple();
        $this->photo($couple, $alice, 1000);
        Date::factory()->create(['couple_id' => $couple->id, 'created_by' => $bob->id, 'title' => 'Picnic']);

        $response = $this->actingAs($alice)->getJson('/api/v1/me/export')->assertOk();

        $response->assertJsonPath('data.user.email', $alice->email)
            ->assertJsonPath('data.couple.dates.0.title', 'Picnic')
            ->assertJsonCount(2, 'data.couple.members')
            ->assertJsonCount(1, 'data.couple.memories.0.photos');

        $body = $response->getContent();
        foreach (['password', 'remember_token', 'public_key', 'nonce', '"mac"', 'storage_key', 'key_id', 'billing_account'] as $secret) {
            $this->assertStringNotContainsString($secret, $body, "Export leaks {$secret}");
        }
    }

    public function test_export_requires_authentication(): void
    {
        $this->getJson('/api/v1/me/export')->assertUnauthorized();
    }
}
