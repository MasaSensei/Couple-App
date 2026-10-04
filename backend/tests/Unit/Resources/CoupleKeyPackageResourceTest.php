<?php

namespace Tests\Unit\Resources;

use App\Http\Resources\Api\V1\Couple\CoupleKeyPackageResource;
use App\Models\CoupleKeyPackage;
use Illuminate\Http\Request;
use Tests\TestCase;

class CoupleKeyPackageResourceTest extends TestCase
{
    public function test_resource_exposes_encrypted_package_data_only(): void
    {
        $package = new CoupleKeyPackage([
            'couple_id' => 10,
            'device_id' => 20,
            'key_id' => 'key-123',
            'encryption_version' => 1,
            'ephemeral_public_key' => 'public-key',
            'nonce' => 'nonce',
            'ciphertext' => 'ciphertext',
            'mac' => 'mac',
            'revoked_at' => null,
        ]);

        $package->id = 1;

        $resource = new CoupleKeyPackageResource($package);

        $data = $resource->toArray(
            Request::create('/'),
        );

        $this->assertSame(1, $data['id']);
        $this->assertSame(20, $data['device_id']);
        $this->assertSame('key-123', $data['key_id']);
        $this->assertSame(1, $data['encryption_version']);
        $this->assertSame(
            'public-key',
            $data['ephemeral_public_key'],
        );

        $this->assertArrayNotHasKey(
            'couple_id',
            $data,
        );

        $this->assertArrayNotHasKey(
            'private_key',
            $data,
        );

        $this->assertArrayNotHasKey(
            'couple_key',
            $data,
        );

        $this->assertArrayNotHasKey(
            'photo_key',
            $data,
        );
    }
}
