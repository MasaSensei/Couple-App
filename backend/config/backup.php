<?php

/*
 * Encrypted PostgreSQL backups. See docs/storage/reliability.md §14.
 *
 * The app holds only the PUBLIC key: it can create backups but never read
 * them. The secret key lives with operators and is passed to
 * db:restore-check / a restore by file path, never via the app's .env.
 */
return [

    'disk' => 'db_backups',

    // Base64 X25519 public key (php artisan db:backup-keygen).
    'public_key' => env('DB_BACKUP_PUBLIC_KEY'),

    // Operator-only. Set in dev/drill environments so the scheduled restore check can run.
    'restore_identity' => env('DB_BACKUP_RESTORE_IDENTITY'),

    // Throwaway database the restore check restores into, then drops.
    'scratch_database' => env('DB_BACKUP_SCRATCH_DATABASE', 'couples_restore_check'),

    // Monitoring: a backup older than this is an alert.
    'max_age_hours' => (int) env('DB_BACKUP_MAX_AGE_HOURS', 26),

];
