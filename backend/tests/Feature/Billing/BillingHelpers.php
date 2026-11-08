<?php

namespace Tests\Feature\Billing;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\CoupleSubscription;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Services\Billing\Providers\MockStore;
use Database\Seeders\SubscriptionPlanSeeder;
use Illuminate\Testing\TestResponse;

trait BillingHelpers
{
    protected function seedPlans(): void
    {
        $this->seed(SubscriptionPlanSeeder::class);
    }

    /** @return array{0: User, 1: User, 2: Couple} */
    protected function makeCouple(): array
    {
        $couple = Couple::factory()->create();
        $a = User::factory()->create();
        $b = User::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $a->id]);
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $b->id]);

        return [$a, $b, $couple];
    }

    protected function store(): MockStore
    {
        return app(MockStore::class);
    }

    /** Full API purchase flow: intent → mock store sheet → server verification. */
    protected function buy(User $user, string $planKey = 'love'): TestResponse
    {
        $intent = $this->actingAs($user)->postJson('/api/v1/couple/subscription/intents', [
            'plan_key' => $planKey,
            'provider' => 'mock',
        ])->assertCreated()->json('data.intent');

        $token = $this->actingAs($user)->postJson('/api/v1/billing/mock/purchases', [
            'product_id' => $intent['product_id'],
            'account_token' => $intent['account_token'],
            'replaces_subscription_id' => $intent['replaces_subscription_id'],
        ])->assertCreated()->json('data.purchase_token');

        return $this->actingAs($user)->postJson('/api/v1/couple/subscription/verify', [
            'provider' => 'mock',
            'product_id' => $intent['product_id'],
            'purchase_token' => $token,
        ]);
    }

    protected function liveSubscription(Couple $couple): ?CoupleSubscription
    {
        return CoupleSubscription::where('couple_id', $couple->id)->live()->first();
    }

    /** Delivers a correctly signed mock webhook. */
    protected function webhook(string $token, string $type = 'changed', ?string $eventId = null): TestResponse
    {
        $hook = $this->store()->webhook($token, $type, $eventId);

        return $this->call('POST', '/api/v1/billing/webhooks/mock', server: [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_MOCK_SIGNATURE' => $hook['signature'],
        ], content: $hook['body']);
    }

    protected function photo(Couple $couple, User $user, int $encryptedSize, array $attributes = []): MemoryPhoto
    {
        $memory = Memory::where('couple_id', $couple->id)->first()
            ?? Memory::factory()->create(['couple_id' => $couple->id, 'created_by' => $user->id]);

        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $memory->id,
            'uploaded_by' => $user->id,
            'storage_key' => "couples/{$couple->id}/memories/{$memory->id}/photos/".fake()->uuid(),
            'mime_type' => 'image/jpeg',
            'file_size' => $encryptedSize - 28,
            'encrypted_size' => $encryptedSize,
            'checksum' => str_repeat('a', 64),
            'encryption_version' => '1',
            'encryption_algorithm' => 'AES-256-GCM',
            'key_id' => 'key-1',
            'nonce' => base64_encode(random_bytes(12)),
            'mac' => base64_encode(random_bytes(16)),
            'status' => 'verified',
            'backup_status' => 'verified',
            ...$attributes,
        ]);
        $photo->save();

        return $photo;
    }
}
