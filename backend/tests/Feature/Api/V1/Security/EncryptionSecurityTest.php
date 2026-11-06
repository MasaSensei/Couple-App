<?php

namespace Tests\Feature\Api\V1\Security;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Phase 5 security properties. The test plays the role of the Flutter client:
 * secrets are generated here and must never be reachable from the server side
 * (database, storage, API responses).
 */
class EncryptionSecurityTest extends TestCase
{
    use RefreshDatabase;

    private const KEY_ID = 'couple-key-1';

    // A minimal JPEG header followed by "private" image bytes.
    private const PLAINTEXT_PHOTO = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00private-photo-pixels\xFF\xD9";

    private Couple $couple;

    private User $userA;

    private User $userB;

    private Memory $memory;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');

        $this->couple = Couple::factory()->create();
        $this->userA = User::factory()->create();
        $this->userB = User::factory()->create();

        foreach ([$this->userA, $this->userB] as $user) {
            CoupleMember::create(['couple_id' => $this->couple->id, 'user_id' => $user->id]);
        }

        $this->memory = Memory::factory()->create([
            'couple_id' => $this->couple->id,
            'created_by' => $this->userA->id,
        ]);
    }

    public function test_server_side_data_cannot_decrypt_photos(): void
    {
        $coupleKey = random_bytes(32);
        $recoveryKey = random_bytes(32);
        $deviceWrappingKey = random_bytes(32);

        $deviceA = $this->device($this->userA);
        $deviceB = $this->device($this->userB);

        // Device A shares the Couple Key with itself and with the partner's device.
        foreach ([$deviceA, $deviceB] as $device) {
            $this->actingAs($this->userA)
                ->postJson('/api/v1/couple/key-packages', $this->keyPackage($device->id, $coupleKey, $deviceWrappingKey))
                ->assertOk();
        }

        $this->actingAs($this->userA)
            ->putJson('/api/v1/couple/recovery-package', [
                ...$this->encrypt($coupleKey, $recoveryKey),
                'key_id' => self::KEY_ID,
                'format_version' => 1,
                'recovery_key' => base64_encode($recoveryKey),
            ])
            ->assertOk()
            ->assertJsonMissingPath('data.package.recovery_key');

        [$photo, $photoKey] = $this->uploadEncryptedPhoto($this->userA, $coupleKey);

        // Storage holds ciphertext only: not an image, no plaintext.
        $stored = Storage::disk('photos_primary')->get($photo->storage_key);
        $this->assertStringNotContainsString('private-photo-pixels', $stored);
        $this->assertStringStartsNotWith("\xFF\xD8", $stored);
        $this->assertFalse(@getimagesizefromstring($stored));

        // The backup holds the same ciphertext, never anything the server decrypted.
        $this->assertSame($stored, Storage::disk('photos_backup')->get($photo->storage_key));

        // No key material or plaintext anywhere in the database or either storage copy.
        $haystack = $this->dumpDatabase();
        foreach (['photos_primary', 'photos_backup'] as $disk) {
            foreach (Storage::disk($disk)->allFiles() as $file) {
                $haystack .= Storage::disk($disk)->get($file);
            }
        }

        foreach ([$coupleKey, $photoKey, $recoveryKey, $deviceWrappingKey, self::PLAINTEXT_PHOTO] as $secret) {
            foreach ($this->encodings($secret) as $encoded) {
                $this->assertStringNotContainsString($encoded, $haystack);
            }
        }

        // Ciphertext + all server metadata is useless without the client-held key.
        $this->assertFalse(openssl_decrypt(
            $stored,
            'aes-256-gcm',
            random_bytes(32),
            OPENSSL_RAW_DATA,
            base64_decode($photo->nonce),
            base64_decode($photo->mac),
            $this->photoAad($photo->id),
        ));
    }

    public function test_partner_downloads_ciphertext_and_decrypts_with_couple_key(): void
    {
        $coupleKey = random_bytes(32);
        $this->device($this->userA);
        $this->seedKeyPackage($this->userA);

        [$photo, $photoKey] = $this->uploadEncryptedPhoto($this->userA, $coupleKey);

        $response = $this->actingAs($this->userB)
            ->get("/api/v1/memory-photos/{$photo->id}/content")
            ->assertOk()
            ->assertHeader('Content-Type', 'application/octet-stream');

        $ciphertext = $response->streamedContent();

        $this->assertSame(self::PLAINTEXT_PHOTO, openssl_decrypt(
            $ciphertext,
            'aes-256-gcm',
            $photoKey,
            OPENSSL_RAW_DATA,
            base64_decode($photo->nonce),
            base64_decode($photo->mac),
            $this->photoAad($photo->id),
        ));

        // Tampering is detected by AES-GCM authentication.
        $ciphertext[0] = chr(ord($ciphertext[0]) ^ 1);

        $this->assertFalse(openssl_decrypt(
            $ciphertext,
            'aes-256-gcm',
            $photoKey,
            OPENSSL_RAW_DATA,
            base64_decode($photo->nonce),
            base64_decode($photo->mac),
            $this->photoAad($photo->id),
        ));
    }

    public function test_other_couple_cannot_download_photo(): void
    {
        $this->seedKeyPackage($this->userA);
        [$photo] = $this->uploadEncryptedPhoto($this->userA, random_bytes(32));

        $outsider = User::factory()->create();
        CoupleMember::create(['couple_id' => Couple::factory()->create()->id, 'user_id' => $outsider->id]);

        $this->actingAs($outsider)
            ->get("/api/v1/memory-photos/{$photo->id}/content")
            ->assertForbidden();
    }

    public function test_checksum_mismatch_fails_verification(): void
    {
        $this->seedKeyPackage($this->userA);

        $ciphertext = random_bytes(64);
        $photoId = $this->createSession($this->userA, $ciphertext, [
            'checksum' => hash('sha256', 'something else'),
        ]);

        $this->post("/api/v1/memory-photos/{$photoId}/upload", [
            'photo' => UploadedFile::fake()->createWithContent('blob', $ciphertext),
        ])->assertOk();

        $this->postJson("/api/v1/memory-photos/{$photoId}/complete")->assertStatus(422);

        $this->assertSame('failed', MemoryPhoto::find($photoId)->status);
        $this->getJson("/api/v1/memories/{$this->memory->id}/photos")
            ->assertJsonCount(0, 'data.photos');
    }

    public function test_encryption_metadata_with_unknown_key_is_rejected(): void
    {
        $this->seedKeyPackage($this->userA);

        $ciphertext = random_bytes(64);
        $this->actingAs($this->userA);

        $photoId = $this->postJson("/api/v1/memories/{$this->memory->id}/photos/upload", [
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
        ])->json('data.photo.id');

        $this->patchJson("/api/v1/memory-photos/{$photoId}/encryption", [
            ...$this->photoMetadata($ciphertext),
            'key_id' => 'not-a-couple-key',
        ])->assertStatus(422);
    }

    public function test_partner_device_can_receive_key_package_but_outsider_device_cannot(): void
    {
        $deviceB = $this->device($this->userB);

        $outsider = User::factory()->create();
        CoupleMember::create(['couple_id' => Couple::factory()->create()->id, 'user_id' => $outsider->id]);
        $outsiderDevice = $this->device($outsider);

        $this->actingAs($this->userA)
            ->postJson('/api/v1/couple/key-packages', $this->keyPackage($deviceB->id))
            ->assertOk();

        $this->actingAs($this->userA)
            ->postJson('/api/v1/couple/key-packages', $this->keyPackage($outsiderDevice->id))
            ->assertNotFound();
    }

    public function test_couple_can_only_have_one_couple_key(): void
    {
        $deviceA = $this->device($this->userA);
        $deviceB = $this->device($this->userB);

        $this->actingAs($this->userA)
            ->postJson('/api/v1/couple/key-packages', $this->keyPackage($deviceA->id))
            ->assertOk();

        // Partner's device must not establish a second, different key.
        $this->actingAs($this->userB)
            ->postJson('/api/v1/couple/key-packages', [
                ...$this->keyPackage($deviceB->id),
                'key_id' => 'another-key',
            ])
            ->assertStatus(409);

        // Same device + same key twice is rejected too.
        $this->actingAs($this->userA)
            ->postJson('/api/v1/couple/key-packages', $this->keyPackage($deviceA->id))
            ->assertStatus(409);
    }

    public function test_couple_devices_lists_active_public_keys_of_both_members(): void
    {
        $deviceA = $this->device($this->userA);
        $deviceB = $this->device($this->userB);
        $this->device($this->userB)->update(['revoked_at' => now()]);
        $this->device(User::factory()->create());

        $this->actingAs($this->userA)
            ->getJson('/api/v1/couple/devices')
            ->assertOk()
            ->assertJsonCount(2, 'data.devices')
            ->assertJsonPath('data.devices.0.id', $deviceA->id)
            ->assertJsonPath('data.devices.0.owner', 'me')
            ->assertJsonPath('data.devices.1.id', $deviceB->id)
            ->assertJsonPath('data.devices.1.owner', 'partner')
            ->assertJsonPath('data.devices.1.public_key', $deviceB->public_key);
    }

    public function test_revoked_device_is_signed_out_and_cannot_re_register(): void
    {
        $tokenA1 = $this->userA->createToken('phone')->plainTextToken;
        $tokenA2 = $this->userA->createToken('tablet')->plainTextToken;

        $identifier = 'phone-identifier';
        $publicKey = base64_encode(random_bytes(32));

        $deviceId = $this->withToken($tokenA1)
            ->postJson('/api/v1/devices', [
                'device_identifier' => $identifier,
                'platform' => 'android',
                'public_key' => $publicKey,
            ])
            ->assertOk()
            ->json('data.device.id');

        $this->seedKeyPackage($this->userA, UserDevice::find($deviceId));
        $this->app['auth']->forgetGuards();

        $this->withToken($tokenA2)
            ->deleteJson("/api/v1/devices/{$deviceId}")
            ->assertOk();

        $this->assertNotNull(UserDevice::find($deviceId)->revoked_at);
        $this->assertDatabaseMissing('couple_key_packages', ['device_id' => $deviceId, 'revoked_at' => null]);

        // The revoked device's token no longer works.
        $this->app['auth']->forgetGuards();
        $this->withToken($tokenA1)->getJson('/api/v1/me')->assertUnauthorized();

        // A new session cannot silently reactivate the revoked device.
        $this->app['auth']->forgetGuards();
        $this->withToken($tokenA2)
            ->postJson('/api/v1/devices', [
                'device_identifier' => $identifier,
                'platform' => 'android',
                'public_key' => $publicKey,
            ])
            ->assertForbidden();
    }

    public function test_changing_device_public_key_revokes_its_old_key_packages(): void
    {
        $device = $this->device($this->userA);
        $this->seedKeyPackage($this->userA, $device);

        $this->actingAs($this->userA)
            ->postJson('/api/v1/devices', [
                'device_identifier' => $device->device_identifier,
                'platform' => 'android',
                'public_key' => base64_encode(random_bytes(32)),
            ])
            ->assertOk();

        $this->assertDatabaseMissing('couple_key_packages', ['device_id' => $device->id, 'revoked_at' => null]);
    }

    public function test_recovery_package_is_private_to_its_owner(): void
    {
        $this->actingAs($this->userA)->getJson('/api/v1/couple/recovery-package')->assertNotFound();

        $payload = [
            ...$this->encrypt(random_bytes(32), random_bytes(32)),
            'key_id' => self::KEY_ID,
            'format_version' => 1,
        ];

        $this->actingAs($this->userA)->putJson('/api/v1/couple/recovery-package', $payload)->assertOk();

        $this->actingAs($this->userA)
            ->getJson('/api/v1/couple/recovery-package')
            ->assertOk()
            ->assertJsonPath('data.package.ciphertext', $payload['ciphertext']);

        $this->actingAs($this->userB)->getJson('/api/v1/couple/recovery-package')->assertNotFound();
    }

    public function test_recovery_package_rejects_malformed_payload(): void
    {
        $this->actingAs($this->userA)
            ->putJson('/api/v1/couple/recovery-package', [
                'key_id' => self::KEY_ID,
                'format_version' => 1,
                'nonce' => base64_encode(random_bytes(8)),
                'ciphertext' => base64_encode(random_bytes(64)),
                'mac' => base64_encode(random_bytes(16)),
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['nonce', 'ciphertext'], 'data.errors');
    }

    private function uploadEncryptedPhoto(User $user, string $coupleKey): array
    {
        $this->actingAs($user);

        $photoId = $this->postJson("/api/v1/memories/{$this->memory->id}/photos/upload", [
            'mime_type' => 'image/jpeg',
            'file_size' => strlen(self::PLAINTEXT_PHOTO),
        ])->assertCreated()->json('data.photo.id');

        // Stand-in for the client's HKDF(coupleKey, photoId).
        $photoKey = hash_hmac('sha256', (string) $photoId, $coupleKey, true);
        $nonce = random_bytes(12);
        $ciphertext = openssl_encrypt(
            self::PLAINTEXT_PHOTO,
            'aes-256-gcm',
            $photoKey,
            OPENSSL_RAW_DATA,
            $nonce,
            $tag,
            $this->photoAad($photoId),
        );

        $this->patchJson("/api/v1/memory-photos/{$photoId}/encryption", [
            ...$this->photoMetadata($ciphertext),
            'nonce' => base64_encode($nonce),
            'mac' => base64_encode($tag),
        ])->assertOk();

        $this->post("/api/v1/memory-photos/{$photoId}/upload", [
            'photo' => UploadedFile::fake()->createWithContent("{$photoId}.enc", $ciphertext),
        ])->assertOk();

        $this->postJson("/api/v1/memory-photos/{$photoId}/complete")
            ->assertOk()
            ->assertJsonPath('data.photo.status', 'verified');

        return [MemoryPhoto::find($photoId), $photoKey];
    }

    private function createSession(User $user, string $ciphertext, array $overrides = []): int
    {
        $this->actingAs($user);

        $photoId = $this->postJson("/api/v1/memories/{$this->memory->id}/photos/upload", [
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
        ])->json('data.photo.id');

        $this->patchJson("/api/v1/memory-photos/{$photoId}/encryption", [
            ...$this->photoMetadata($ciphertext),
            ...$overrides,
        ])->assertOk();

        return $photoId;
    }

    private function photoMetadata(string $ciphertext): array
    {
        return [
            'encryption_version' => 1,
            'encryption_algorithm' => 'AES-256-GCM',
            'key_id' => self::KEY_ID,
            'nonce' => base64_encode(random_bytes(12)),
            'mac' => base64_encode(random_bytes(16)),
            'encrypted_size' => strlen($ciphertext),
            'checksum' => hash('sha256', $ciphertext),
        ];
    }

    private function photoAad(int $photoId): string
    {
        return self::KEY_ID.':1:'.$photoId;
    }

    private function device(User $user): UserDevice
    {
        return UserDevice::create([
            'user_id' => $user->id,
            'device_identifier' => fake()->uuid(),
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);
    }

    private function seedKeyPackage(User $user, ?UserDevice $device = null): void
    {
        $device ??= $this->device($user);

        $this->couple->keyPackages()->create([
            ...$this->keyPackage($device->id),
            'device_id' => $device->id,
        ]);
    }

    private function keyPackage(int $deviceId, ?string $coupleKey = null, ?string $wrappingKey = null): array
    {
        return [
            ...$this->encrypt($coupleKey ?? random_bytes(32), $wrappingKey ?? random_bytes(32)),
            'device_id' => $deviceId,
            'key_id' => self::KEY_ID,
            'encryption_version' => 1,
            'ephemeral_public_key' => base64_encode(random_bytes(32)),
        ];
    }

    private function encrypt(string $plaintext, string $key): array
    {
        $nonce = random_bytes(12);
        $ciphertext = openssl_encrypt($plaintext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $nonce, $tag);

        return [
            'nonce' => base64_encode($nonce),
            'ciphertext' => base64_encode($ciphertext),
            'mac' => base64_encode($tag),
        ];
    }

    private function encodings(string $secret): array
    {
        return [
            $secret,
            base64_encode($secret),
            rtrim(strtr(base64_encode($secret), '+/', '-_'), '='),
            bin2hex($secret),
        ];
    }

    private function dumpDatabase(): string
    {
        $tables = DB::select("select table_name from information_schema.tables where table_schema = 'public'");

        return collect($tables)
            ->map(fn ($table) => json_encode(DB::table($table->table_name)->get()))
            ->implode("\n");
    }
}
