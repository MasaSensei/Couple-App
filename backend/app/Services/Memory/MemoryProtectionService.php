<?php

namespace App\Services\Memory;

use App\Models\Couple;
use App\Models\MemoryPhoto;
use Illuminate\Support\Carbon;

/**
 * What the couple sees about their photos' safety. Derived from the server
 * workflow (MemoryPhoto::protectionStatus), never from client input, and
 * phrased without infrastructure details.
 */
class MemoryProtectionService
{
    /** Internal protection status → user-facing status. */
    public const USER_STATUS = [
        'protected' => 'protected',
        'backup_pending' => 'backing_up',
        'restoring' => 'restoring',
        'degraded' => 'needs_attention',
        'failed' => 'upload_failed',
        'pending_upload' => 'uploading',
        'deleted' => 'deleted',
    ];

    public static function userStatus(MemoryPhoto $photo): string
    {
        return self::USER_STATUS[$photo->protectionStatus()];
    }

    public function summary(Couple $couple): array
    {
        $query = MemoryPhoto::query()
            ->whereHas('memory', fn ($query) => $query->where('couple_id', $couple->id))
            ->whereNull('deleted_at');

        $counts = [];
        foreach (MemoryPhoto::protectionCounts(clone $query) as $status => $total) {
            $user = self::USER_STATUS[$status];
            $counts[$user] = ($counts[$user] ?? 0) + $total;
        }
        unset($counts['deleted']);

        $count = fn (string $status) => $counts[$status] ?? 0;
        $stored = (clone $query)->where('status', 'verified');

        return [
            // Photos that reached the server; uploads in progress are counted separately.
            'photos' => $count('protected') + $count('backing_up') + $count('restoring') + $count('needs_attention'),
            'protected' => $count('protected'),
            'backing_up' => $count('backing_up'),
            'restoring' => $count('restoring'),
            'needs_attention' => $count('needs_attention'),
            'uploading' => $count('uploading'),
            'upload_failed' => $count('upload_failed'),
            'state' => match (true) {
                $count('needs_attention') + $count('upload_failed') > 0 => 'needs_attention',
                $count('restoring') > 0 => 'restoring',
                $count('backing_up') + $count('uploading') > 0 => 'backing_up',
                $count('protected') > 0 => 'protected',
                default => 'empty',
            },
            'last_integrity_check_at' => $this->iso((clone $stored)->max('integrity_checked_at')),
            'last_verified_backup_at' => $this->iso((clone $stored)->max('backup_verified_at')),
        ];
    }

    private function iso(?string $timestamp): ?string
    {
        return $timestamp === null ? null : Carbon::parse($timestamp)->toISOString();
    }
}
