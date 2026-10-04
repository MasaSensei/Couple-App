<?php

namespace Tests\Unit\Models;

use App\Models\Couple;
use App\Models\CoupleKeyPackage;
use App\Models\CoupleMember;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Tests\TestCase;

class CoupleKeyPackageTest extends TestCase
{
    public function test_couple_key_package_belongs_to_couple(): void
    {
        $package = new CoupleKeyPackage();

        $this->assertInstanceOf(
            BelongsTo::class,
            $package->couple(),
        );
    }

    public function test_couple_key_package_belongs_to_device(): void
    {
        $package = new CoupleKeyPackage();

        $this->assertInstanceOf(
            BelongsTo::class,
            $package->device(),
        );
    }

    public function test_couple_has_many_key_packages(): void
    {
        $couple = new Couple();

        $this->assertInstanceOf(
            HasMany::class,
            $couple->keyPackages(),
        );
    }

    public function test_device_has_many_key_packages(): void
    {
        $device = new UserDevice();

        $this->assertInstanceOf(
            HasMany::class,
            $device->coupleKeyPackages(),
        );
    }

    public function test_authenticated_user_can_list_their_couple_key_packages(): void
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

        $package = CoupleKeyPackage::create([
            'couple_id' => $couple->id,
            'device_id' => $device->id,
            'key_id' => fake()->uuid(),
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
        ]);

        $response = $this->actingAs($user)
            ->getJson('/api/v1/couple/key-packages');

        $response
            ->assertOk()
            ->assertJsonPath(
                'success',
                true,
            )
            ->assertJsonPath(
                'data.packages.0.id',
                $package->id,
            )
            ->assertJsonPath(
                'data.packages.0.device_id',
                $device->id,
            );
    }

    public function test_user_cannot_list_another_couples_key_packages(): void
    {
        $user = User::factory()->create();

        $ownCouple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $ownCouple->id,
            'user_id' => $user->id,
        ]);

        $otherUser = User::factory()->create();

        $otherCouple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $otherCouple->id,
            'user_id' => $otherUser->id,
        ]);

        $otherDevice = UserDevice::create([
            'user_id' => $otherUser->id,
            'device_identifier' => fake()->uuid(),
            'device_name' => 'Other Device',
            'platform' => 'android',
            'public_key' => base64_encode(
                random_bytes(32),
            ),
        ]);

        $otherPackage = CoupleKeyPackage::create([
            'couple_id' => $otherCouple->id,
            'device_id' => $otherDevice->id,
            'key_id' => fake()->uuid(),
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
        ]);

        $response = $this->actingAs($user)
            ->getJson('/api/v1/couple/key-packages');

        $response
            ->assertOk()
            ->assertJsonMissing([
                'id' => $otherPackage->id,
            ]);
    }

    public function test_revoked_key_packages_are_not_listed(): void
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

        $package = CoupleKeyPackage::create([
            'couple_id' => $couple->id,
            'device_id' => $device->id,
            'key_id' => fake()->uuid(),
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
            'revoked_at' => now(),
        ]);

        $response = $this->actingAs($user)
            ->getJson('/api/v1/couple/key-packages');

        $response
            ->assertOk()
            ->assertJsonMissing([
                'id' => $package->id,
            ]);
    }

    public function test_user_without_a_couple_cannot_list_key_packages(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)
            ->getJson('/api/v1/couple/key-packages');

        $response->assertUnprocessable();
    }
}
