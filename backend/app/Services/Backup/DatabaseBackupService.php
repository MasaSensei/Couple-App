<?php

namespace App\Services\Backup;

use App\Models\DatabaseBackup;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Throwable;

/**
 * Encrypted logical backups of PostgreSQL (pg_dump custom format).
 *
 * The plaintext dump never touches disk: pg_dump's stdout is encrypted as it
 * streams. Only ciphertext is written to a temp file, uploaded, and then
 * re-downloaded and hashed before the backup counts as succeeded.
 */
class DatabaseBackupService
{
    /** Tables whose row counts are recorded and compared by the restore check. */
    public const KEY_TABLES = [
        'users', 'couples', 'couple_members', 'memories', 'memory_photos',
        'user_devices', 'couple_key_packages', 'couple_key_recovery_packages',
    ];

    public function __construct(
        private readonly BackupEncryptor $encryptor,
    ) {}

    public function backup(): DatabaseBackup
    {
        $publicKey = config('backup.public_key');

        if (blank($publicKey)) {
            throw new RuntimeException('DB_BACKUP_PUBLIC_KEY is not configured.');
        }

        $backup = DatabaseBackup::create([
            'status' => 'running',
            'started_at' => now(),
            'object_key' => sprintf('postgres/%s-%s.dump.enc', config('database.connections.pgsql.database'), now()->utc()->format('Ymd\THis\Z')),
            'table_counts' => $this->tableCounts(DB::connection()),
        ]);

        $tmp = $this->tempPath('backup');

        try {
            $this->dumpEncrypted($tmp, $publicKey);

            $sha256 = hash_file('sha256', $tmp);
            $size = filesize($tmp);

            $stream = fopen($tmp, 'rb');
            Storage::disk(config('backup.disk'))->writeStream($backup->object_key, $stream);
            is_resource($stream) && fclose($stream);

            // Trust the store only after reading the object back.
            $stored = Storage::disk(config('backup.disk'))->readStream($backup->object_key);
            $context = hash_init('sha256');
            hash_update_stream($context, $stored);
            fclose($stored);

            if (! hash_equals($sha256, hash_final($context))) {
                throw new RuntimeException('Uploaded backup does not match the local checksum.');
            }

            $backup->update([
                'status' => 'succeeded',
                'sha256' => $sha256,
                'size_bytes' => $size,
                'finished_at' => now(),
            ]);
        } catch (Throwable $exception) {
            $backup->update([
                'status' => 'failed',
                'error' => mb_substr(class_basename($exception).': '.$exception->getMessage(), 0, 255),
                'finished_at' => now(),
            ]);

            Log::error('Database backup failed.', ['backup_id' => $backup->id, 'error' => $exception::class]);

            throw $exception;
        } finally {
            @unlink($tmp);
        }

        return $backup;
    }

    /**
     * Restores a backup into a throwaway database and checks it. Needs the
     * operator's secret key. The scratch database is dropped unless $keep.
     */
    public function restoreCheck(DatabaseBackup $backup, string $secretKey, bool $keep = false): DatabaseBackup
    {
        $scratch = config('backup.scratch_database');
        $tmp = $this->tempPath('restore');
        $problems = [];
        $notes = [];

        try {
            $this->download($backup, $tmp);

            $this->runClient(['dropdb', '--if-exists', $scratch]);
            $this->runClient(['createdb', $scratch]);
            $this->restoreInto($tmp, $scratch, $secretKey);

            Config::set('database.connections.restore_check', [
                ...config('database.connections.pgsql'),
                'database' => $scratch,
            ]);
            DB::purge('restore_check');
            $restored = DB::connection('restore_check');

            foreach ($this->tableCounts($restored) as $table => $count) {
                $expected = $backup->table_counts[$table] ?? null;
                $notes[] = "{$table}={$count}";

                // Counts are taken just before the dump, so concurrent writes can differ slightly.
                if ($expected !== null && $count !== $expected) {
                    $notes[] = "({$table} expected {$expected} at backup start)";
                }
            }

            // Every photo the app considers stored must still be decryptable from this backup.
            $undecryptable = $restored->table('memory_photos')
                ->where('status', 'verified')
                ->whereNull('primary_purged_at')
                ->where(fn ($query) => $query
                    ->whereNull('checksum')->orWhereNull('nonce')->orWhereNull('mac')->orWhereNull('key_id'))
                ->count();

            // A data problem in the source DB, not a restore fault: reported, shown as `degraded` in the app.
            if ($undecryptable > 0) {
                $notes[] = "WARNING {$undecryptable} verified photo(s) without decryption metadata";
            }

            $orphans = $restored->table('memory_photos')
                ->leftJoin('memories', 'memories.id', '=', 'memory_photos.memory_id')
                ->whereNull('memories.id')
                ->count();

            if ($orphans > 0) {
                $problems[] = "{$orphans} photo row(s) without a memory";
            }

            DB::disconnect('restore_check');
        } catch (Throwable $exception) {
            $problems[] = class_basename($exception).': '.$exception->getMessage();
        } finally {
            @unlink($tmp);

            if (! $keep) {
                DB::disconnect('restore_check');

                try {
                    $this->runClient(['dropdb', '--if-exists', $scratch]);
                } catch (Throwable $exception) {
                    report($exception);
                }
            }
        }

        $backup->update([
            'restore_checked_at' => now(),
            'restore_result' => $problems === [] ? 'passed' : 'failed',
            'restore_detail' => implode('; ', [...$problems, ...$notes]),
        ]);

        if ($problems !== []) {
            Log::critical('Database restore check failed.', ['backup_id' => $backup->id]);
        }

        return $backup->refresh();
    }

    /**
     * Disaster restore into a NEW or empty database, by object key, so it works
     * when the original database (and its database_backups table) is gone.
     * Refuses a target that already has tables: it never overwrites data.
     */
    public function restoreToDatabase(string $objectKey, string $database, string $secretKey, ?string $expectedSha256 = null): array
    {
        $tmp = $this->tempPath('restore');

        try {
            $this->runClient(['createdb', $database], allowFailure: true);

            Config::set('database.connections.restore_target', [
                ...config('database.connections.pgsql'),
                'database' => $database,
            ]);
            DB::purge('restore_target');
            $target = DB::connection('restore_target');

            if ($target->table('information_schema.tables')->where('table_schema', 'public')->exists()) {
                throw new RuntimeException("Database {$database} is not empty; refusing to restore over it.");
            }

            $in = Storage::disk(config('backup.disk'))->readStream($objectKey);
            $out = fopen($tmp, 'wb');
            stream_copy_to_stream($in, $out);
            fclose($in);
            fclose($out);

            if ($expectedSha256 !== null && ! hash_equals($expectedSha256, hash_file('sha256', $tmp))) {
                throw new RuntimeException('Backup does not match the expected SHA-256.');
            }

            // Authenticated decryption still rejects any tampered or truncated file.
            $this->restoreInto($tmp, $database, $secretKey);

            return $this->tableCounts($target);
        } finally {
            @unlink($tmp);
            DB::disconnect('restore_target');
        }
    }

    /** Downloads and verifies the stored ciphertext against the recorded SHA-256. */
    public function download(DatabaseBackup $backup, string $path): void
    {
        $in = Storage::disk(config('backup.disk'))->readStream($backup->object_key);
        $out = fopen($path, 'wb');
        stream_copy_to_stream($in, $out);
        fclose($in);
        fclose($out);

        if (! hash_equals((string) $backup->sha256, hash_file('sha256', $path))) {
            throw new RuntimeException('Stored backup does not match its recorded checksum.');
        }
    }

    /** Decrypts $encryptedPath straight into pg_restore; plaintext never touches disk. */
    public function restoreInto(string $encryptedPath, string $database, string $secretKey): void
    {
        $process = $this->open(['pg_restore', '--no-owner', '--no-privileges', '--exit-on-error', '--dbname', $database], stdin: true);
        $in = fopen($encryptedPath, 'rb');

        try {
            $this->encryptor->decrypt($in, $process['pipes'][0], $secretKey);
        } catch (Throwable $exception) {
            // Reap pg_restore and drop its stderr file; the decrypt error is the one that matters.
            fclose($process['pipes'][0]);
            rescue(fn () => $this->close($process, 'pg_restore'), report: false);

            throw $exception;
        } finally {
            fclose($in);
        }

        fclose($process['pipes'][0]);
        $this->close($process, 'pg_restore');
    }

    private function dumpEncrypted(string $path, string $publicKey): void
    {
        $database = config('database.connections.pgsql.database');
        $process = $this->open(['pg_dump', '--format=custom', '--no-owner', '--no-privileges', $database]);
        $out = fopen($path, 'wb');

        try {
            $this->encryptor->encrypt($process['pipes'][1], $out, $publicKey);
        } catch (Throwable $exception) {
            rescue(fn () => $this->close($process, 'pg_dump'), report: false);

            throw $exception;
        } finally {
            fclose($out);
        }

        $this->close($process, 'pg_dump');
    }

    private function runClient(array $command, bool $allowFailure = false): void
    {
        try {
            $this->close($this->open($command), $command[0]);
        } catch (RuntimeException $exception) {
            // e.g. createdb when the database already exists.
            if (! $allowFailure) {
                throw $exception;
            }
        }
    }

    /** @return array{process: resource, pipes: array<int, resource>, stderr: string} */
    private function open(array $command, bool $stdin = false): array
    {
        $connection = config('database.connections.pgsql');

        $env = [
            'PGHOST' => $connection['host'],
            'PGPORT' => (string) $connection['port'],
            'PGUSER' => $connection['username'],
            'PGPASSWORD' => $connection['password'],
            'PATH' => getenv('PATH') ?: '/usr/local/bin:/usr/bin:/bin',
        ];

        // stderr goes to a file so a full pipe can never deadlock the dump.
        $stderr = $this->tempPath('stderr');

        $process = proc_open($command, [
            0 => $stdin ? ['pipe', 'r'] : ['file', '/dev/null', 'r'],
            1 => ['pipe', 'w'],
            2 => ['file', $stderr, 'w'],
        ], $pipes, null, $env);

        if (! is_resource($process)) {
            throw new RuntimeException("Could not start {$command[0]}.");
        }

        return ['process' => $process, 'pipes' => $pipes, 'stderr' => $stderr];
    }

    private function close(array $process, string $name): void
    {
        if (isset($process['pipes'][1]) && is_resource($process['pipes'][1])) {
            stream_get_contents($process['pipes'][1]);
            fclose($process['pipes'][1]);
        }

        $code = proc_close($process['process']);
        // PostgreSQL client errors name tables/databases, never the password (passed via env).
        $error = trim((string) @file_get_contents($process['stderr']));
        @unlink($process['stderr']);

        if ($code !== 0) {
            throw new RuntimeException("{$name} exited with code {$code}: ".mb_substr($error, 0, 160));
        }
    }

    private function tableCounts($connection): array
    {
        return collect(self::KEY_TABLES)
            ->mapWithKeys(fn (string $table) => [$table => $connection->table($table)->count()])
            ->all();
    }

    private function tempPath(string $prefix): string
    {
        $directory = storage_path('app/private/backup-tmp');
        is_dir($directory) || mkdir($directory, 0700, true);

        return $directory.'/'.$prefix.'-'.bin2hex(random_bytes(8));
    }
}
