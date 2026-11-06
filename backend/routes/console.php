<?php

use App\Jobs\BackupMemoryPhoto;
use App\Jobs\PurgeMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\DatabaseBackup;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Services\Backup\DatabaseBackupService;
use App\Services\Storage\PhotoReconciliationService;
use App\Services\Storage\StorageHealthService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Safety net for lost jobs (queue outage, worker crash). Only `pending` is
// retried; `failed` has exhausted its retries and waits for an operator.
Artisan::command('photos:backup-pending {--older-than=15 : Minutes since last change}', function () {
    $count = 0;

    MemoryPhoto::withTrashed()
        ->where('status', 'verified')
        ->where('backup_status', 'pending')
        ->whereNull('primary_purged_at')
        ->where('updated_at', '<=', now()->subMinutes((int) $this->option('older-than')))
        ->select('id')
        ->chunkById(500, function ($photos) use (&$count) {
            foreach ($photos as $photo) {
                BackupMemoryPhoto::dispatch($photo->id);
                $count++;
            }
        });

    $this->info("Dispatched {$count} backup job(s).");
})->purpose('Re-dispatch photo backups that are still pending');

Schedule::command('photos:backup-pending')->everyTenMinutes()->withoutOverlapping();

// Re-hash each copy at least every --days. --limit spreads the download cost
// (each check reads the whole object from both stores) across the week.
Artisan::command('photos:verify-integrity {--days=7} {--limit=500}', function () {
    $ids = MemoryPhoto::withTrashed()
        ->where('status', 'verified')
        ->whereNull('primary_purged_at')
        ->where(fn ($query) => $query
            ->whereNull('integrity_checked_at')
            ->orWhere('integrity_checked_at', '<=', now()->subDays((int) $this->option('days'))))
        ->orderByRaw('integrity_checked_at IS NOT NULL, integrity_checked_at')
        ->limit((int) $this->option('limit'))
        ->pluck('id');

    $ids->each(fn (int $id) => VerifyMemoryPhotoIntegrity::dispatch($id));

    // Repairs whose job was lost (queue outage, worker crash). Unique jobs make this a no-op otherwise.
    $repairs = MemoryPhoto::withTrashed()
        ->where('repair_status', 'pending')
        ->where('updated_at', '<=', now()->subMinutes(30))
        ->pluck('id');

    $repairs->each(fn (int $id) => RepairMemoryPhoto::dispatch($id));

    $this->info("Dispatched {$ids->count()} integrity check(s), {$repairs->count()} repair(s).");
})->purpose('Queue integrity checks for photos not verified recently');

Schedule::command('photos:verify-integrity')->hourly()->withoutOverlapping();

// Retention. Never deletes anything itself: it trashes abandoned uploads and
// queues PurgeMemoryPhoto, which re-checks every condition before deleting.
Artisan::command('photos:purge', function () {
    $abandoned = MemoryPhoto::query()
        ->where('status', '!=', 'verified')
        ->where('created_at', '<=', now()->subHours(config('photos.abandoned_upload_hours')))
        ->get();

    $abandoned->each(function (MemoryPhoto $photo): void {
        $photo->delete();
        PhotoStorageAudit::record($photo->id, 'trash', 'succeeded', 'system', "Upload abandoned ({$photo->status}).");
    });

    $due = MemoryPhoto::onlyTrashed()
        ->where(fn ($query) => $query
            ->where(fn ($query) => $query
                ->whereNull('primary_purged_at')
                ->where('deleted_at', '<=', now()->subDays(config('photos.trash_retention_days'))))
            ->orWhere('primary_purged_at', '<=', now()->subDays(config('photos.backup_retention_days'))))
        ->pluck('id');

    $due->each(fn (int $id) => PurgeMemoryPhoto::dispatch($id));

    $this->info("Trashed {$abandoned->count()} abandoned upload(s), queued {$due->count()} purge(s).");
})->purpose('Apply photo trash and backup retention');

Schedule::command('photos:purge')->dailyAt('03:30')->withoutOverlapping();

// Encrypted PostgreSQL backup (docs/storage/reliability.md §14).
Artisan::command('db:backup', function (DatabaseBackupService $service) {
    $backup = $service->backup();

    $this->info("Backup #{$backup->id} succeeded: {$backup->size_bytes} bytes, sha256 {$backup->sha256}.");
})->purpose('Dump, encrypt and upload the database, then verify the stored copy');

Schedule::command('db:backup')->dailyAt('02:00')->withoutOverlapping();

// Operator command: needs the backup SECRET key, which the app server must not hold in production.
Artisan::command('db:restore-check {--identity= : Path to the secret key file} {--backup= : Backup id (default: latest)} {--keep : Keep the scratch database}',
    function (DatabaseBackupService $service) {
        $path = $this->option('identity') ?: config('backup.restore_identity');

        if (blank($path) || ! is_readable($path)) {
            $this->error('A readable --identity file (or DB_BACKUP_RESTORE_IDENTITY) is required.');

            return 1;
        }

        $backup = $this->option('backup')
            ? DatabaseBackup::findOrFail($this->option('backup'))
            : DatabaseBackup::latestSucceeded();

        if ($backup === null) {
            $this->error('No succeeded backup to check.');

            return 1;
        }

        $started = microtime(true);
        $backup = $service->restoreCheck($backup, file_get_contents($path), (bool) $this->option('keep'));
        $seconds = round(microtime(true) - $started, 1);

        $this->line("Backup #{$backup->id}: restore {$backup->restore_result} in {$seconds}s");
        $this->line($backup->restore_detail);

        return $backup->restore_result === 'passed' ? 0 : 1;
    })->purpose('Restore a database backup into a scratch database and verify it');

// Runs only where an operator identity is configured (dev, drill environment).
Schedule::command('db:restore-check')->weeklyOn(0, '04:00')->withoutOverlapping()
    ->when(fn () => filled(config('backup.restore_identity')));

Artisan::command('db:backup-keygen', function () {
    $keypair = sodium_crypto_box_keypair();

    $this->line('DB_BACKUP_PUBLIC_KEY='.base64_encode(sodium_crypto_box_publickey($keypair)));
    $this->warn('Secret key (store offline with operators, never in the app .env):');
    $this->line(base64_encode(sodium_crypto_box_secretkey($keypair)));
})->purpose('Generate a key pair for database backups');

Artisan::command('photos:reconcile {--no-queue : Report only, do not queue integrity checks}', function (PhotoReconciliationService $service) {
    $report = $service->run(queueChecks: ! $this->option('no-queue'));

    foreach ($report as $key => $value) {
        $this->line(str_pad($key, 20).(is_array($value) ? count($value).($value ? '  '.implode(', ', array_slice($value, 0, 10)) : '') : $value));
    }

    return $service->isClean($report) ? 0 : 1;
})->purpose('Compare photo rows with stored objects (report only, never deletes)');

Schedule::command('photos:reconcile')->dailyAt('05:00')->withoutOverlapping();

// Evaluates storage/backup alerts and routes them to the `alerts` log channel
// (file by default, Slack via ALERT_LOG_CHANNELS). Each alert is re-sent at most
// every 6 h while active, and a "resolved" line is written when it clears.
Artisan::command('storage:alerts', function (StorageHealthService $health) {
    $alerts = collect($health->alerts())->keyBy('code');
    $previous = Cache::get('storage:alerts:active', []);

    foreach ($alerts as $code => $alert) {
        if (Cache::add("storage:alerts:sent:{$code}", true, now()->addHours(6))) {
            Log::channel('alerts')->{$alert['level']}($alert['message'], ['code' => $code]);
        }
    }

    foreach (array_diff($previous, $alerts->keys()->all()) as $code) {
        Cache::forget("storage:alerts:sent:{$code}");
        Log::channel('alerts')->notice("Resolved: {$code}", ['code' => $code]);
    }

    Cache::forever('storage:alerts:active', $alerts->keys()->all());

    $alerts->each(fn ($alert) => $this->line(strtoupper($alert['level']).'  '.$alert['message']));
    $this->info($alerts->isEmpty() ? 'No active alerts.' : "{$alerts->count()} active alert(s).");

    return $alerts->contains('level', 'critical') ? 1 : 0;
})->purpose('Evaluate storage and backup alerts');

Schedule::command('storage:alerts')->everyFifteenMinutes()->withoutOverlapping();

// Disaster restore (docs/storage/disaster-recovery.md §4). Operator-only: needs the secret key.
// Restores into a new/empty database and never overwrites one that has tables.
Artisan::command('db:restore {--object= : Object key in the db-backups bucket (default: latest succeeded backup)} {--database= : New or empty target database} {--identity= : Path to the secret key file} {--sha256= : Expected SHA-256 (optional when the DB is gone)}',
    function (DatabaseBackupService $service) {
        $path = $this->option('identity') ?: config('backup.restore_identity');

        if (blank($this->option('database')) || blank($path) || ! is_readable($path)) {
            $this->error('--database and a readable --identity are required.');

            return 1;
        }

        $object = $this->option('object');
        $sha256 = $this->option('sha256');

        if (blank($object)) {
            $backup = DatabaseBackup::latestSucceeded() ?? throw new RuntimeException('No succeeded backup recorded; pass --object.');
            [$object, $sha256] = [$backup->object_key, $sha256 ?: $backup->sha256];
        }

        $started = microtime(true);
        $counts = $service->restoreToDatabase($object, $this->option('database'), file_get_contents($path), $sha256);

        $this->info(sprintf('Restored %s into %s in %.1fs.', $object, $this->option('database'), microtime(true) - $started));
        foreach ($counts as $table => $count) {
            $this->line(str_pad($table, 32).$count);
        }

        return 0;
    })->purpose('Restore an encrypted database backup into a new, empty database');

// Run on every deploy (also run by the appearance migration). Adds new themes /
// templates from database/data/appearance_catalog.json; never deletes and never
// overrides what admins set (status, premium, order).
Artisan::command('appearance:sync-catalog', function (\App\Services\Appearance\AppearanceCatalog $catalog) {
    $counts = $catalog->sync();

    $this->info("Synced {$counts['themes']} theme(s) and {$counts['templates']} Photo Booth template(s).");
})->purpose('Sync the theme and Photo Booth catalog from the app definitions');
