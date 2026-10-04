<?php

namespace Tests\Unit\Services;

use App\Models\Couple;
use App\Models\CoupleKeyPackage;
use App\Models\User;
use App\Models\UserDevice;
use App\Services\CoupleKeyPackageService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\CoupleMember;

class CoupleKeyPackageServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_a_key_package_for_their_active_device(): void
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
            'revoked_at' => null,
        ]);

        $data = [
            'device_id' => $device->id,
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

        $service = app(CoupleKeyPackageService::class);

        $package = $service->create(
            $user,
            $data,
        );

        $this->assertInstanceOf(
            CoupleKeyPackage::class,
            $package,
        );

        $this->assertDatabaseHas(
            'couple_key_packages',
            [
                'id' => $package->id,
                'couple_id' => $couple->id,
                'device_id' => $device->id,
                'key_id' => $data['key_id'],
            ],
        );
    }

    public function test_user_cannot_create_a_key_package_for_another_users_device(): void
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
            'revoked_at' => null,
        ]);

        $data = [
            'device_id' => $device->id,
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

        $service = app(CoupleKeyPackageService::class);

        $this->expectException(\Symfony\Component\HttpKernel\Exception\HttpException::class);

        $service->create(
            $user,
            $data,
        );
    }

    public function test_revoked_device_cannot_create_a_key_package(): void
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

        $data = [
            'device_id' => $device->id,
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

        $service = app(CoupleKeyPackageService::class);

        $this->expectException(
            \Symfony\Component\HttpKernel\Exception\HttpException::class,
        );

        $service->create(
            $user,
            $data,
        );
    }
}
