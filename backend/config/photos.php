<?php

/*
 * Photo retention. See docs/storage/reliability.md §13.
 *
 * user delete ──► trash (object untouched) ──trash_retention_days──► primary purged
 *   ──backup_retention_days──► backup purged, row removed
 */
return [

    // How long a deleted photo stays in the couple's trash and can be restored.
    'trash_retention_days' => (int) env('PHOTOS_TRASH_RETENTION_DAYS', 30),

    // Extra time the backup copy is kept after the primary is purged
    // (protects against a purge that should not have happened).
    'backup_retention_days' => (int) env('PHOTOS_BACKUP_RETENTION_DAYS', 30),

    // Uploads that never reached `verified` are moved to the trash after this.
    'abandoned_upload_hours' => (int) env('PHOTOS_ABANDONED_UPLOAD_HOURS', 24),

];
