<?php

namespace App\Services\Billing;

use App\Models\Couple;
use Closure;
use Illuminate\Support\Facades\DB;

/**
 * Logical storage quota of a couple. See docs/billing/subscriptions.md §7.
 *
 *  - Counted: the ciphertext size (`encrypted_size`, the bytes actually
 *    stored) of verified, non-trashed photos. Photo Booth output is a normal
 *    encrypted photo and counts the same way.
 *  - Counted once: the backup replica is an internal reliability cost and
 *    never doubles the couple's usage.
 *  - Reserved, not used: uploads still in progress (pending/uploading) for
 *    at most `photos.abandoned_upload_hours`. They block over-filling via
 *    parallel uploads but are never shown as usage.
 *  - Not counted: trashed photos. Deleting frees space immediately; in
 *    exchange a restore needs free space (the photo stays in the trash and
 *    downloadable state is unchanged until then).
 *
 * The quota only ever blocks *adding* bytes. Viewing, downloading, deleting
 * and every other feature keep working when full or after a downgrade, and
 * nothing is ever deleted because a subscription ended.
 */
class StorageQuotaService
{
    public function __construct(
        private readonly EntitlementService $entitlements,
    ) {}

    /** @return array{used_bytes: int, trash_bytes: int, reserved_bytes: int, limit_bytes: int, remaining_bytes: int, is_full: bool, photo_count: int} */
    public function usage(Couple $couple, ?int $exceptPhotoId = null): array
    {
        $size = 'COALESCE(memory_photos.encrypted_size, memory_photos.file_size, 0)';

        $row = DB::table('memory_photos')
            ->join('memories', 'memories.id', '=', 'memory_photos.memory_id')
            ->where('memories.couple_id', $couple->id)
            ->whereNull('memory_photos.primary_purged_at')
            ->when($exceptPhotoId, fn ($query) => $query->where('memory_photos.id', '!=', $exceptPhotoId))
            ->selectRaw("
                COALESCE(SUM(CASE WHEN memory_photos.deleted_at IS NULL AND memory_photos.status = 'verified' THEN {$size} END), 0) AS used,
                COALESCE(SUM(CASE WHEN memory_photos.deleted_at IS NOT NULL AND memory_photos.status = 'verified' THEN {$size} END), 0) AS trash,
                COALESCE(SUM(CASE WHEN memory_photos.deleted_at IS NULL AND memory_photos.status IN ('pending', 'uploading')
                    AND memory_photos.created_at > ? THEN {$size} END), 0) AS reserved,
                COUNT(CASE WHEN memory_photos.deleted_at IS NULL AND memory_photos.status = 'verified' THEN 1 END) AS photos
            ", [now()->subHours(config('photos.abandoned_upload_hours'))])
            ->first();

        $limit = $this->entitlements->forCouple($couple)->storageLimitBytes();
        $used = (int) $row->used;

        return [
            'used_bytes' => $used,
            'trash_bytes' => (int) $row->trash,
            'reserved_bytes' => (int) $row->reserved,
            'limit_bytes' => $limit,
            'remaining_bytes' => max(0, $limit - $used),
            'is_full' => $used >= $limit,
            'photo_count' => (int) $row->photos,
        ];
    }

    /**
     * Runs $write only if $bytes more fit in the couple's quota. The couple
     * row is locked for the check and the write, so two partners uploading at
     * once cannot both squeeze into the last free megabytes.
     *
     * @template T
     *
     * @param  Closure(): T  $write
     * @return T
     *
     * @throws StorageQuotaExceeded
     */
    public function reserve(Couple $couple, int $bytes, ?int $exceptPhotoId, Closure $write): mixed
    {
        return DB::transaction(function () use ($couple, $bytes, $exceptPhotoId, $write) {
            Couple::whereKey($couple->id)->lockForUpdate()->first();

            $this->assertFits($couple, $bytes, $exceptPhotoId);

            return $write();
        });
    }

    /** @throws StorageQuotaExceeded */
    public function assertFits(Couple $couple, int $bytes, ?int $exceptPhotoId = null): void
    {
        $usage = $this->usage($couple, $exceptPhotoId);

        if ($usage['used_bytes'] + $usage['reserved_bytes'] + max(0, $bytes) > $usage['limit_bytes']) {
            throw new StorageQuotaExceeded($this->usage($couple));
        }
    }
}
