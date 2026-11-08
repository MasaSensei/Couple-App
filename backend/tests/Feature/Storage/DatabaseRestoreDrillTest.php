<?php

namespace Tests\Feature\Storage;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\DatabaseBackup;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Services\Backup\DatabaseBackupService;
use App\Services\Storage\PhotoReconciliationService;
use Illuminate\Foundation\Testing\DatabaseTruncation;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * STEP 14 scenario F: the database is lost and restored from an encrypted
 * backup. Photo rows and the objects in storage must be reconciled, and every
 * photo that existed at backup time must be found again.
 */
class DatabaseRestoreDrillTest extends TestCase
{
    use DatabaseTruncation;

    private const SCRATCH = 'couples_test_restore_drill';

    protected function tearDown(): void
    {
        // Committed rows would leak into the transaction-based tests that run after this class.
        $this->truncateTablesForAllConnections();

        parent::tearDown();
    }

    public function test_f_database_loss_restore_and_reconciliation(): void
    {
        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
        Storage::fake('db_backups');
        Queue::fake();

        $keypair = sodium_crypto_box_keypair();
        config([
            'backup.public_key' => base64_encode(sodium_crypto_box_publickey($keypair)),
            'backup.scratch_database' => self::SCRATCH,
        ]);

        $user = User::factory()->create();
        $couple = Couple::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $user->id]);
        $memory = Memory::factory()->create(['couple_id' => $couple->id, 'created_by' => $user->id]);

        $photos = collect(range(1, 3))->map(fn () => $this->storedPhoto($memory));

        $backup = app(DatabaseBackupService::class)->backup();

        // A photo uploaded after the backup: its object survives, its row will not (RPO window).
        $late = $this->storedPhoto($memory);

        // Disaster: the database is gone. Restore the backup into a fresh database.
        $restored = app(DatabaseBackupService::class)->restoreCheck(
            $backup, base64_encode(sodium_crypto_box_secretkey($keypair)), keep: true,
        );
        $this->assertSame('passed', $restored->restore_result);

        $live = config('database.connections.pgsql.database');

        try {
            config(['database.connections.pgsql.database' => self::SCRATCH]);
            DB::purge('pgsql');

            // Every photo from backup time is back, with the metadata needed to decrypt it.
            $this->assertSame(
                $photos->pluck('storage_key')->sort()->values()->all(),
                MemoryPhoto::orderBy('storage_key')->pluck('storage_key')->all(),
            );
            $this->assertSame(0, MemoryPhoto::whereNull('nonce')->orWhereNull('mac')->count());

            $report = app(PhotoReconciliationService::class)->run(queueChecks: false);

            $this->assertSame([], $report['missing_primary']);
            $this->assertSame([], $report['missing_backup']);
            // The late upload is reported, not deleted: its object is still in both stores.
            $this->assertSame([$late->storage_key], $report['orphan_primary']);
            $this->assertSame([$late->storage_key], $report['orphan_backup']);
            Storage::disk('photos_primary')->assertExists($late->storage_key);
        } finally {
            config(['database.connections.pgsql.database' => $live]);
            DB::purge('pgsql');
            DB::purge('restore_check');
            app(DatabaseBackupService::class)->restoreCheck(DatabaseBackup::find($backup->id), base64_encode(sodium_crypto_box_secretkey($keypair)));
        }
    }

    private function storedPhoto(Memory $memory): MemoryPhoto
    {
        $ciphertext = random_bytes(256);

        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $memory->id,
            'storage_key' => 'couples/'.$memory->couple_id.'/memories/'.$memory->id.'/photos/'.fake()->uuid(),
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'encryption_version' => '1', 'encryption_algorithm' => 'AES-256-GCM', 'key_id' => 'key-1',
            'nonce' => base64_encode(random_bytes(12)), 'mac' => base64_encode(random_bytes(16)),
            'checksum' => hash('sha256', $ciphertext),
            'encrypted_size' => strlen($ciphertext),
            'status' => 'verified',
            'backup_status' => 'verified',
        ]);
        $photo->save();

        Storage::disk('photos_primary')->put($photo->storage_key, $ciphertext);
        Storage::disk('photos_backup')->put($photo->storage_key, $ciphertext);

        return $photo;
    }
}
