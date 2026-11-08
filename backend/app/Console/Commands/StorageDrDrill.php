<?php

namespace App\Console\Commands;

use App\Models\Couple;
use App\Models\CoupleKeyPackage;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Models\UserDevice;
use App\Services\Memory\MemoryPhotoService;
use App\Services\Storage\PhotoReconciliationService;
use App\Services\Storage\PhotoStorage;
use Illuminate\Console\Command;
use Illuminate\Http\UploadedFile;
use RuntimeException;

/**
 * Disaster-recovery drill for non-production environments (docs/storage/disaster-recovery.md).
 *
 *   prepare  live env: create a drill couple with N encrypted photos through the real
 *            upload/verify/backup workflow, keeping the drill's client key OUTSIDE the
 *            server (a local file standing in for the users' phones).
 *   verify   disaster env (restored DB + empty replacement primary): reconcile, repair
 *            from backup, re-verify checksums, decrypt every photo as a client would,
 *            and scan both stores and the DB for plaintext.
 *
 * The client side is a PHP stand-in using the same AES-256-GCM + AAD layout as the
 * app; the Flutter decrypt path itself is covered by its own tests.
 */
class StorageDrDrill extends Command
{
    protected $signature = 'storage:dr-drill {phase : prepare|verify} {--photos=5} {--client-dir= : Where the drill client key lives}';

    protected $description = 'Run a storage disaster-recovery drill (non-production only)';

    private const MARKER = 'DR-DRILL-PLAINTEXT';

    public function handle(): int
    {
        if (app()->isProduction()) {
            $this->error('Refusing to run a DR drill in production.');

            return 1;
        }

        $dir = $this->option('client-dir') ?: storage_path('app/private/dr-drill-client');
        is_dir($dir) || mkdir($dir, 0700, true);

        return match ($this->argument('phase')) {
            'prepare' => $this->prepare($dir),
            'verify' => $this->verify($dir),
            default => tap(1, fn () => $this->error('Phase must be prepare or verify.')),
        };
    }

    private function prepare(string $dir): int
    {
        $started = microtime(true);
        $coupleKey = random_bytes(32);

        $user = User::factory()->create(['email' => 'dr-drill-'.now()->format('YmdHis').'@example.test']);
        $couple = Couple::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $user->id]);
        $memory = Memory::factory()->create(['couple_id' => $couple->id, 'created_by' => $user->id, 'title' => 'DR drill']);
        $device = UserDevice::create([
            'user_id' => $user->id, 'device_identifier' => 'dr-drill', 'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);
        $keyId = 'dr-drill-'.bin2hex(random_bytes(4));
        // Opaque placeholder package: the real one is wrapped on a device; the server never sees the key.
        (new CoupleKeyPackage)->forceFill([
            'couple_id' => $couple->id, 'device_id' => $device->id, 'key_id' => $keyId, 'encryption_version' => 1,
            'ephemeral_public_key' => 'drill', 'nonce' => 'drill', 'ciphertext' => 'drill', 'mac' => 'drill',
        ])->save();

        $service = app(MemoryPhotoService::class);
        $expected = [];

        for ($i = 0; $i < (int) $this->option('photos'); $i++) {
            $plaintext = $this->jpeg($i);
            $session = $service->createUploadSession($user, $memory, ['mime_type' => 'image/jpeg', 'file_size' => strlen($plaintext)]);
            $photo = $session['photo'];

            // "Client" encryption: key never leaves this process except to the client-dir file.
            $nonce = random_bytes(12);
            $aad = "{$keyId}:1:{$photo->id}";
            $ciphertext = openssl_encrypt($plaintext, 'aes-256-gcm', $this->photoKey($coupleKey, $photo->id), OPENSSL_RAW_DATA, $nonce, $tag, $aad);

            $service->updateEncryptionMetadata($photo, [
                'encryption_version' => 1, 'encryption_algorithm' => 'AES-256-GCM', 'key_id' => $keyId,
                'nonce' => base64_encode($nonce), 'mac' => base64_encode($tag),
                'encrypted_size' => strlen($ciphertext), 'checksum' => hash('sha256', $ciphertext),
            ]);

            $tmp = tempnam(sys_get_temp_dir(), 'drill');
            file_put_contents($tmp, $ciphertext);
            $service->upload($user, $photo->refresh(), new UploadedFile($tmp, 'c.bin', 'application/octet-stream', null, true));
            $service->complete($photo->refresh());
            @unlink($tmp);

            $photo->refresh();
            $expected[$photo->id] = hash('sha256', $plaintext);
            $this->line("photo #{$photo->id}: {$photo->protectionStatus()} (".strlen($ciphertext).' B ciphertext)');
        }

        file_put_contents("{$dir}/client.json", json_encode([
            'couple_id' => $couple->id, 'key_id' => $keyId,
            'couple_key' => base64_encode($coupleKey), 'plaintext_sha256' => $expected,
        ]));
        chmod("{$dir}/client.json", 0600);

        $unprotected = MemoryPhoto::whereIn('id', array_keys($expected))->get()->reject(fn ($p) => $p->protectionStatus() === 'protected');
        $this->info(sprintf('Prepared couple #%d with %d photo(s) in %.1fs; %d not yet protected.',
            $couple->id, count($expected), microtime(true) - $started, $unprotected->count()));

        return $unprotected->isEmpty() ? 0 : 1;
    }

    private function verify(string $dir): int
    {
        $client = json_decode((string) @file_get_contents("{$dir}/client.json"), true)
            ?? throw new RuntimeException('Run the prepare phase first.');
        $ids = array_map('intval', array_keys($client['plaintext_sha256']));
        $failures = 0;
        $check = function (bool $ok, string $label) use (&$failures): void {
            $this->line(($ok ? 'PASS  ' : 'FAIL  ').$label);
            $ok || $failures++;
        };

        $t0 = microtime(true);
        $photos = MemoryPhoto::whereIn('id', $ids)->get()->keyBy('id');
        $check($photos->count() === count($ids), "DB restore: {$photos->count()}/".count($ids).' drill photo rows present');

        $primary = app(PhotoStorage::class);
        $missingBefore = $photos->filter(fn ($p) => $primary->checkIntegrity($p->storage_key, $p->checksum, $p->encrypted_size) === 'missing')->count();
        $this->line("primary copies missing before repair: {$missingBefore}");

        // Reconcile queues integrity checks; with QUEUE_CONNECTION=sync they run (and repair) inline.
        $t1 = microtime(true);
        app(PhotoReconciliationService::class)->run('dr-drill');
        $repairSeconds = microtime(true) - $t1;

        foreach ($photos as $photo) {
            $photo->refresh();
            $primaryState = $primary->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size);
            $backupState = app('photos.backup')->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size);
            $check($primaryState === 'ok' && $backupState === 'ok', "photo #{$photo->id}: checksum primary={$primaryState} backup={$backupState}");
            $check($photo->protectionStatus() === 'protected', "photo #{$photo->id}: protection={$photo->protectionStatus()}");

            // Client-side decrypt with the legitimate key, from the restored primary.
            $stream = $primary->readStream($photo->storage_key);
            $ciphertext = stream_get_contents($stream);
            fclose($stream);
            $plaintext = openssl_decrypt($ciphertext, 'aes-256-gcm',
                $this->photoKey(base64_decode($client['couple_key']), $photo->id), OPENSSL_RAW_DATA,
                base64_decode($photo->nonce), base64_decode($photo->mac), "{$photo->key_id}:1:{$photo->id}");
            $check($plaintext !== false && hash('sha256', $plaintext) === $client['plaintext_sha256'][$photo->id],
                "photo #{$photo->id}: client decrypts restored copy to the original image");
            $check(! str_starts_with($ciphertext, "\xFF\xD8\xFF") && ! str_contains($ciphertext, self::MARKER),
                "photo #{$photo->id}: stored object is not a readable JPEG");
        }

        // No plaintext anywhere server-side: objects in both stores and every text column in the DB.
        $leaks = collect([$primary, app('photos.backup')])->sum(function (PhotoStorage $store) use ($photos) {
            return $photos->filter(function ($photo) use ($store) {
                $stream = $store->readStream($photo->storage_key);
                $bytes = stream_get_contents($stream);
                fclose($stream);

                return str_contains($bytes, self::MARKER) || str_contains($bytes, "\xFF\xD8\xFF");
            })->count();
        });
        $dbLeak = collect(\DB::select("SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND data_type IN ('text', 'character varying')"))
            ->contains(fn ($c) => \DB::table($c->table_name)->where($c->column_name, 'like', '%'.self::MARKER.'%')->exists()
                || \DB::table($c->table_name)->where($c->column_name, 'like', '%'.$client['couple_key'].'%')->exists());
        $check($leaks === 0, 'no plaintext image bytes in either store');
        $check(! $dbLeak, 'no plaintext marker or couple key anywhere in the database');

        $this->info(sprintf('Repair/reconcile %.1fs, whole verify %.1fs, failures=%d', $repairSeconds, microtime(true) - $t0, $failures));

        return $failures === 0 ? 0 : 1;
    }

    private function photoKey(string $coupleKey, int $photoId): string
    {
        return hash_hkdf('sha256', $coupleKey, 32, "photo:{$photoId}");
    }

    /** A real JPEG with a text marker, so "can it be opened as an image?" is meaningful. */
    private function jpeg(int $i): string
    {
        $image = imagecreatetruecolor(640, 480);
        for ($y = 0; $y < 480; $y += 8) {
            imagefilledrectangle($image, 0, $y, 639, $y + 7, imagecolorallocate($image, random_int(0, 255), random_int(0, 255), random_int(0, 255)));
        }
        imagestring($image, 5, 20, 20, self::MARKER." #{$i}", imagecolorallocate($image, 255, 255, 255));
        ob_start();
        imagejpeg($image, null, 85);
        imagedestroy($image);

        // The marker also travels as a JPEG comment so byte scans can find it.
        return substr_replace(ob_get_clean(), "\xFF\xFE".pack('n', strlen(self::MARKER) + 2).self::MARKER, 2, 0);
    }
}
