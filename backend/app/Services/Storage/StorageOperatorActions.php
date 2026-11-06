<?php

namespace App\Services\Storage;

use App\Jobs\BackupMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use RuntimeException;

/**
 * The only storage operations an admin can trigger. None of them reads,
 * returns or decrypts photo content, and none deletes anything: each one only
 * queues the same server workflow the scheduler would run, and is audited.
 */
class StorageOperatorActions
{
    public function retryBackup(MemoryPhoto $photo, User $admin): void
    {
        $this->authorize($admin);

        if ($photo->status !== 'verified' || $photo->isPurged() || $photo->backup_status === 'verified') {
            throw new RuntimeException('This photo has no backup to retry.');
        }

        $photo->forceFill(['backup_status' => 'pending', 'backup_error' => null])->save();
        BackupMemoryPhoto::dispatch($photo->id);

        $this->audit($photo, 'admin_retry_backup', $admin);
    }

    public function verifyIntegrity(MemoryPhoto $photo, User $admin): void
    {
        $this->authorize($admin);

        if ($photo->status !== 'verified' || $photo->isPurged()) {
            throw new RuntimeException('Only stored photos can be verified.');
        }

        VerifyMemoryPhotoIntegrity::dispatch($photo->id);

        $this->audit($photo, 'admin_verify', $admin);
    }

    public function requestRepair(MemoryPhoto $photo, User $admin): void
    {
        $this->authorize($admin);

        if ($photo->status !== 'verified' || $photo->isPurged()) {
            throw new RuntimeException('Only stored photos can be repaired.');
        }

        // Also re-arms a repair that ended `failed` (e.g. after the operator fixed a store).
        $photo->forceFill(['repair_status' => 'pending'])->save();
        RepairMemoryPhoto::dispatch($photo->id, "user:{$admin->id}");

        $this->audit($photo, 'admin_repair', $admin);
    }

    private function authorize(User $admin): void
    {
        if (! $admin->is_admin) {
            throw new AuthorizationException('Only administrators can run storage operations.');
        }
    }

    private function audit(MemoryPhoto $photo, string $action, User $admin): void
    {
        PhotoStorageAudit::record($photo->id, $action, 'queued', "user:{$admin->id}");
    }
}
