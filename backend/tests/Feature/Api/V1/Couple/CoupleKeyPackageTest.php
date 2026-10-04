<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\Couple;
use App\Models\CoupleKeyPackage;
use App\Models\CoupleMember;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CoupleKeyPackageTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_create_a_key_package(): void
    {
        $user = User::factory()->create();

        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $device = UserDevice::create([
            'user_id' => $user->id,
            'device_identifier' => fake()->uuid(),
            'device_name' => 'Test Device',
            'platform' => 'android',
            'public_key' => base64_encode(
                random_bytes(32),
            ),
        ]);

        $payload = $this->validPayload($device->id);

        $response = $this->actingAs($user)
            ->postJson(
                '/api/v1/couple/key-packages',
                $payload,
            );

        $response
            ->assertOk()
            ->assertJsonPath(
                'success',
                true,
            )
            ->assertJsonPath(
                'data.package.device_id',
                $device->id,
            )
            ->assertJsonPath(
                'data.package.key_id',
                $payload['key_id'],
            );

        $this->assertDatabaseHas(
            'couple_key_packages',
            [
                'couple_id' => $couple->id,
                'device_id' => $device->id,
                'key_id' => $payload['key_id'],
            ],
        );
    }

    public function test_user_cannot_create_a_package_for_another_users_device(): void
    {
        $user = User::factory()->create();

        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $otherUser = User::factory()->create();

        $device = UserDevice::create([
            'user_id' => $otherUser->id,
            'device_identifier' => fake()->uuid(),
            'device_name' => 'Other Device',
            'platform' => 'android',
            'public_key' => base64_encode(
                random_bytes(32),
            ),
        ]);

        $response = $this->actingAs($user)
            ->postJson(
                '/api/v1/couple/key-packages',
                $this->validPayload($device->id),
            );

        $response->assertNotFound();

        $this->assertDatabaseCount(
            'couple_key_packages',
            0,
        );
    }

    public function test_revoked_device_cannot_create_a_package(): void
    {
        $user = User::factory()->create();

        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $device = UserDevice::create([
            'user_id' => $user->id,
            'device_identifier' => fake()->uuid(),
            'device_name' => 'Revoked Device',
            'platform' => 'android',
            'public_key' => base64_encode(
                random_bytes(32),
            ),
            'revoked_at' => now(),
        ]);

        $response = $this->actingAs($user)
            ->postJson(
                '/api/v1/couple/key-packages',
                $this->validPayload($device->id),
            );

        $response->assertNotFound();

        $this->assertDatabaseCount(
            'couple_key_packages',
            0,
        );
    }

    public function test_unauthenticated_user_cannot_create_a_package(): void
    {
        $response = $this->postJson(
            '/api/v1/couple/key-packages',
            $this->validPayload(1),
        );

        $response->assertUnauthorized();
    }

    public function test_request_rejects_invalid_binary_lengths(): void
    {
        $user = User::factory()->create();

        $device = UserDevice::create([
            'user_id' => $user->id,
            'device_identifier' => fake()->uuid(),
            'device_name' => 'Test Device',
            'platform' => 'android',
            'public_key' => base64_encode(
                random_bytes(32),
            ),
        ]);

        $payload = $this->validPayload($device->id);

        $payload['ephemeral_public_key'] = base64_encode(
            random_bytes(16),
        );

        $response = $this->actingAs($user)
            ->postJson(
                '/api/v1/couple/key-packages',
                $payload,
            );

        $response
            ->assertUnprocessable()
            ->assertJsonPath(
                'data.errors.ephemeral_public_key.0',
                'The ephemeral public key must contain exactly 32 bytes.',
            );
    }

    public function test_response_does_not_expose_plaintext_secrets(): void
    {
        $user = User::factory()->create();

        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $device = UserDevice::create([
            'user_id' => $user->id,
            'device_identifier' => fake()->uuid(),
            'device_name' => 'Test Device',
            'platform' => 'android',
            'public_key' => base64_encode(
                random_bytes(32),
            ),
        ]);

        $payload = $this->validPayload($device->id);

        $response = $this->actingAs($user)
            ->postJson(
                '/api/v1/couple/key-packages',
                $payload,
            );

        $response
            ->assertOk()
            ->assertJsonMissingPath(
                'data.package.couple_key',
            )
            ->assertJsonMissingPath(
                'data.package.private_key',
            )
            ->assertJsonMissingPath(
                'data.package.photo_key',
            );
    }

    private function validPayload(int $deviceId): array
    {
        return [
            'device_id' => $deviceId,
            'key_id' => '550e8400-e29b-41d4-a716-446655440000',
            'encryption_version' => 1,
            'ephemeral_public_key' => base64_encode(
                random_bytes(32),
            ),
            'nonce' => base64_encode(
                random_bytes(12),
            ),
            'ciphertext' => base64_encode(
                random_bytes(32),
            ),
            'mac' => base64_encode(
                random_bytes(16),
            ),
        ];
    }
}
