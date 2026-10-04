<?php

namespace Tests\Feature\Api\V1\Devices;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserDeviceTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_register_a_device(): void
    {
        $user = User::factory()->create();

        $payload = [
            'device_identifier' => 'device-123',
            'device_name' => 'My Android Phone',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ];

        $response = $this
            ->actingAs($user)
            ->postJson('/api/v1/devices', $payload);

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.device.device_identifier',
                'device-123',
            )
            ->assertJsonPath(
                'data.device.device_name',
                'My Android Phone',
            )
            ->assertJsonPath(
                'data.device.platform',
                'android',
            );

        $this->assertDatabaseHas('user_devices', [
            'user_id' => $user->id,
            'device_identifier' => 'device-123',
            'device_name' => 'My Android Phone',
            'platform' => 'android',
        ]);
    }

    public function test_user_can_only_list_their_own_devices(): void
    {
        $user = User::factory()->create();
        $otherUser = User::factory()->create();

        $user->devices()->create([
            'device_identifier' => 'my-device',
            'device_name' => 'My Phone',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);

        $otherUser->devices()->create([
            'device_identifier' => 'other-device',
            'device_name' => 'Other Phone',
            'platform' => 'ios',
            'public_key' => base64_encode(random_bytes(32)),
        ]);

        $response = $this
            ->actingAs($user)
            ->getJson('/api/v1/devices');

        $response
            ->assertOk()
            ->assertJsonCount(1, 'data.devices')
            ->assertJsonPath(
                'data.devices.0.device_identifier',
                'my-device',
            )
            ->assertJsonPath(
                'data.devices.0.device_name',
                'My Phone',
            );

        $response->assertJsonMissing([
            'device_identifier' => 'other-device',
        ]);
    }

    public function test_user_can_revoke_their_own_device(): void
    {
        $user = User::factory()->create();

        $device = $user->devices()->create([
            'device_identifier' => 'my-device',
            'device_name' => 'My Phone',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);

        $response = $this
            ->actingAs($user)
            ->deleteJson("/api/v1/devices/{$device->id}");

        $response
            ->assertOk()
            ->assertJsonPath(
                'message',
                'Device revoked successfully.',
            );

        $this->assertDatabaseHas('user_devices', [
            'id' => $device->id,
            'user_id' => $user->id,
        ]);

        $device->refresh();

        $this->assertNotNull($device->revoked_at);
    }

    public function test_user_cannot_revoke_another_users_device(): void
    {
        $user = User::factory()->create();
        $otherUser = User::factory()->create();

        $device = $otherUser->devices()->create([
            'device_identifier' => 'other-device',
            'device_name' => 'Other Phone',
            'platform' => 'ios',
            'public_key' => base64_encode(random_bytes(32)),
        ]);

        $response = $this
            ->actingAs($user)
            ->deleteJson("/api/v1/devices/{$device->id}");

        $response->assertNotFound();

        $device->refresh();

        $this->assertNull($device->revoked_at);
    }

    public function test_revoked_device_remains_in_device_list(): void
    {
        $user = User::factory()->create();

        $device = $user->devices()->create([
            'device_identifier' => 'revoked-device',
            'device_name' => 'Old Phone',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
            'revoked_at' => now(),
        ]);

        $response = $this
            ->actingAs($user)
            ->getJson('/api/v1/devices');

        $response
            ->assertOk()
            ->assertJsonCount(1, 'data.devices')
            ->assertJsonPath(
                'data.devices.0.device_identifier',
                'revoked-device',
            )
            ->assertJsonPath(
                'data.devices.0.device_name',
                'Old Phone',
            );

        $this->assertDatabaseHas('user_devices', [
            'id' => $device->id,
        ]);
    }

    public function test_registering_the_same_device_updates_existing_device(): void
    {
        $user = User::factory()->create();

        $user->devices()->create([
            'device_identifier' => 'same-device',
            'device_name' => 'Old Phone Name',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);

        $newPublicKey = base64_encode(random_bytes(32));

        $response = $this
            ->actingAs($user)
            ->postJson('/api/v1/devices', [
                'device_identifier' => 'same-device',
                'device_name' => 'Updated Phone Name',
                'platform' => 'android',
                'public_key' => $newPublicKey,
            ]);

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.device.device_identifier',
                'same-device',
            )
            ->assertJsonPath(
                'data.device.device_name',
                'Updated Phone Name',
            )
            ->assertJsonPath(
                'data.device.public_key',
                $newPublicKey,
            );

        $this->assertDatabaseCount('user_devices', 1);

        $this->assertDatabaseHas('user_devices', [
            'user_id' => $user->id,
            'device_identifier' => 'same-device',
            'device_name' => 'Updated Phone Name',
            'public_key' => $newPublicKey,
        ]);
    }

    public function test_unauthenticated_user_cannot_access_device_endpoints(): void
    {
        $response = $this->postJson('/api/v1/devices', [
            'device_identifier' => 'device-123',
            'device_name' => 'My Phone',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);

        $response->assertUnauthorized();

        $response = $this->getJson('/api/v1/devices');

        $response->assertUnauthorized();

        $user = User::factory()->create();

        $device = $user->devices()->create([
            'device_identifier' => 'device-123',
            'device_name' => 'My Phone',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);

        $response = $this->deleteJson(
            "/api/v1/devices/{$device->id}",
        );

        $response->assertUnauthorized();
    }

    public function test_private_key_sent_by_client_is_never_stored(): void
    {
        $user = User::factory()->create();

        $privateKey = base64_encode(random_bytes(32));

        $response = $this
            ->actingAs($user)
            ->postJson('/api/v1/devices', [
                'device_identifier' => 'device-private-key-test',
                'device_name' => 'My Phone',
                'platform' => 'android',
                'public_key' => base64_encode(random_bytes(32)),
                'private_key' => $privateKey,
            ]);

        $response
            ->assertOk()
            ->assertJsonMissing([
                'private_key' => $privateKey,
            ]);

        $this->assertDatabaseHas('user_devices', [
            'user_id' => $user->id,
            'device_identifier' => 'device-private-key-test',
            'public_key' => $response->json(
                'data.device.public_key',
            ),
        ]);
    }

    public function test_device_list_includes_revoked_at_for_revoked_device(): void
    {
        $user = User::factory()->create();

        $device = $user->devices()->create([
            'device_identifier' => 'revoked-device',
            'device_name' => 'Old Phone',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
            'revoked_at' => now(),
        ]);

        $response = $this
            ->actingAs($user)
            ->getJson('/api/v1/devices');

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.devices.0.id',
                $device->id,
            )
            ->assertJsonPath(
                'data.devices.0.device_identifier',
                'revoked-device',
            )
            ->assertJsonPath(
                'data.devices.0.revoked_at',
                fn($value) => $value !== null,
            );
    }

    public function test_device_registration_rejects_invalid_public_key(): void
    {
        $user = User::factory()->create();

        $response = $this
            ->actingAs($user)
            ->postJson('/api/v1/devices', [
                'device_identifier' => 'invalid-key-device',
                'device_name' => 'My Phone',
                'platform' => 'android',
                'public_key' => base64_encode(random_bytes(16)),
            ]);

        $response
            ->assertUnprocessable()
            ->assertJsonPath(
                'data.errors.public_key.0',
                'The public key must contain exactly 32 bytes.',
            );

        $this->assertDatabaseMissing('user_devices', [
            'user_id' => $user->id,
            'device_identifier' => 'invalid-key-device',
        ]);
    }

    public function test_device_response_does_not_expose_internal_user_id(): void
    {
        $user = User::factory()->create();

        $response = $this
            ->actingAs($user)
            ->postJson('/api/v1/devices', [
                'device_identifier' => 'response-contract-device',
                'device_name' => 'My Phone',
                'platform' => 'android',
                'public_key' => base64_encode(random_bytes(32)),
            ]);

        $response
            ->assertOk()
            ->assertJsonMissingPath('data.device.user_id');
    }

    public function test_device_response_does_not_expose_private_key(): void
    {
        $user = User::factory()->create();

        $response = $this
            ->actingAs($user)
            ->postJson('/api/v1/devices', [
                'device_identifier' => 'private-key-response-test',
                'device_name' => 'My Phone',
                'platform' => 'android',
                'public_key' => base64_encode(random_bytes(32)),
                'private_key' => base64_encode(random_bytes(32)),
            ]);

        $response
            ->assertOk()
            ->assertJsonMissingPath('data.device.private_key');
    }
}
