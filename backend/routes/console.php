<?php

use App\Jobs\BackupMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\MemoryPhoto;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
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
