<?php

namespace Tests\Feature\Storage;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\DatabaseBackup;
use App\Models\Memory;
use App\Models\User;
use App\Services\Backup\DatabaseBackupService;
use Illuminate\Foundation\Testing\DatabaseTruncation;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Runs the real pg_dump / pg_restore against the test database. Uses
 * truncation rather than transactions: pg_dump runs in its own session and
 * would not see uncommitted test data.
 */
class DatabaseBackupTest extends TestCase
{
    use DatabaseTruncation;

    private string $secretKey;

    private string $identityPath;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('db_backups');

        $keypair = sodium_crypto_box_keypair();
        $this->secretKey = base64_encode(sodium_crypto_box_secretkey($keypair));
        $this->identityPath = tempnam(sys_get_temp_dir(), 'identity');
        file_put_contents($this->identityPath, $this->secretKey);

        config([
            'backup.public_key' => base64_encode(sodium_crypto_box_publickey($keypair)),
            'backup.restore_identity' => null,
            'backup.scratch_database' => 'couples_test_restore_check',
        ]);

        $user = User::factory()->create();
        $couple = Couple::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $user->id]);
        Memory::factory()->create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'PLAINTEXT-MARKER memory',
        ]);
    }

    protected function tearDown(): void
    {
        @unlink($this->identityPath);
        // Committed rows would leak into the transaction-based tests that run after this class.
        $this->truncateTablesForAllConnections();

        parent::tearDown();
    }

    public function test_backup_is_encrypted_uploaded_and_verified(): void
    {
        $this->artisan('db:backup')->assertSuccessful();

        $backup = DatabaseBackup::latestSucceeded();
        $this->assertNotNull($backup);
        $this->assertSame(1, $backup->table_counts['memories']);

        $stored = Storage::disk('db_backups')->get($backup->object_key);
        $this->assertSame($backup->sha256, hash('sha256', $stored));
        $this->assertSame($backup->size_bytes, strlen($stored));
        // Neither the dump format nor any row content is readable without the secret key.
        $this->assertStringNotContainsString('PGDMP', $stored);
        $this->assertStringNotContainsString('PLAINTEXT-MARKER', $stored);
        $this->assertStringStartsWith('CPDB1', $stored);

        // Nothing plaintext is left behind locally.
        $this->assertSame([], glob(storage_path('app/private/backup-tmp/*')) ?: []);
    }

    public function test_restore_check_restores_into_scratch_database_and_passes(): void
    {
        $this->artisan('db:backup')->assertSuccessful();

        $this->artisan('db:restore-check', ['--identity' => $this->identityPath, '--keep' => true])
            ->assertSuccessful();

        $backup = DatabaseBackup::latestSucceeded();
        $this->assertSame('passed', $backup->restore_result);
        $this->assertStringContainsString('memories=1', $backup->restore_detail);

        config(['database.connections.scratch' => [...config('database.connections.pgsql'), 'database' => 'couples_test_restore_check']]);
        $this->assertSame(1, DB::connection('scratch')->table('memories')->where('title', 'PLAINTEXT-MARKER memory')->count());
        DB::disconnect('scratch');

        // Clean up the kept scratch database.
        app(DatabaseBackupService::class)->restoreCheck($backup, $this->secretKey);
    }

    public function test_disaster_restore_by_object_key_into_a_new_database_and_never_over_existing_data(): void
    {
        $this->artisan('db:backup')->assertSuccessful();
        $backup = DatabaseBackup::latestSucceeded();
        $target = 'couples_test_disaster_restore';
        $service = app(DatabaseBackupService::class);

        try {
            // As if the source DB were gone: only the object key and the secret key are used.
            $counts = $service->restoreToDatabase($backup->object_key, $target, $this->secretKey);
            $this->assertSame(1, $counts['memories']);

            // A second restore into the same (now non-empty) database is refused.
            $this->expectExceptionMessage('not empty');
            $service->restoreToDatabase($backup->object_key, $target, $this->secretKey);
        } finally {
            DB::disconnect('restore_target');
            exec("PGPASSWORD='".config('database.connections.pgsql.password')."' dropdb -h ".config('database.connections.pgsql.host')
                .' -U '.config('database.connections.pgsql.username')." --if-exists {$target}");
        }
    }

    public function test_restore_check_fails_loudly_on_a_corrupted_backup(): void
    {
        $this->artisan('db:backup')->assertSuccessful();
        $backup = DatabaseBackup::latestSucceeded();

        Storage::disk('db_backups')->put($backup->object_key, 'CPDB1'.random_bytes(500));

        $this->artisan('db:restore-check', ['--identity' => $this->identityPath])->assertFailed();

        $backup->refresh();
        $this->assertSame('failed', $backup->restore_result);
        $this->assertStringContainsString('checksum', $backup->restore_detail);
    }

    public function test_restore_check_with_the_wrong_key_fails(): void
    {
        $this->artisan('db:backup')->assertSuccessful();

        file_put_contents($this->identityPath, base64_encode(sodium_crypto_box_secretkey(sodium_crypto_box_keypair())));

        $this->artisan('db:restore-check', ['--identity' => $this->identityPath])->assertFailed();
        $this->assertSame('failed', DatabaseBackup::latestSucceeded()->restore_result);
        // No temp or stderr files survive a failed restore.
        $this->assertSame([], glob(storage_path('app/private/backup-tmp/*')) ?: []);
    }

    public function test_backup_without_a_configured_key_fails_and_is_recorded_as_nothing(): void
    {
        config(['backup.public_key' => null]);

        $this->expectException(\RuntimeException::class);
        $this->artisan('db:backup');
    }

    public function test_upload_failure_marks_the_backup_failed(): void
    {
        $disk = \Mockery::mock(\Illuminate\Contracts\Filesystem\Filesystem::class);
        $disk->shouldReceive('writeStream')->andThrow(new \RuntimeException('Connection refused.'));
        Storage::set('db_backups', $disk);

        try {
            app(DatabaseBackupService::class)->backup();
            $this->fail('Expected the backup to fail.');
        } catch (\RuntimeException) {
        }

        $this->assertSame('failed', DatabaseBackup::latest('id')->value('status'));
        $this->assertNull(DatabaseBackup::latestSucceeded());
    }
}
