<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;

class MemoryPhoto extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = [
        'memory_id',
        'uploaded_by',
        'storage_key',
        'original_filename',
        'mime_type',
        'file_size',
        'width',
        'height',
        'checksum',
        'encryption_version',
        'encryption_algorithm',
        'key_id',
        'nonce',
        'mac',
        'encrypted_size',
        'status',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'encrypted_size' => 'integer',
            'width' => 'integer',
            'height' => 'integer',
            'file_size' => 'integer',
            'sort_order' => 'integer',
            'deleted_at' => 'datetime',
            'backup_verified_at' => 'datetime',
            'integrity_checked_at' => 'datetime',
            'primary_purged_at' => 'datetime',
            'backup_purged_at' => 'datetime',
        ];
    }

    /** Last moment a trashed photo can still be restored by the couple. */
    public function restorableUntil(): ?Carbon
    {
        return $this->deleted_at?->copy()->addDays(config('photos.trash_retention_days'));
    }

    public function isRestorable(): bool
    {
        return $this->trashed()
            && $this->status === 'verified'
            && ! $this->isPurged()
            && $this->restorableUntil()->isFuture();
    }

    /** The primary copy is gone for good (retention ended); only the backup may remain. */
    public function isPurged(): bool
    {
        return $this->primary_purged_at !== null;
    }

    protected static function booted(): void
    {
        // `checksum` is the trusted reference for every copy. Once verified it is
        // immutable, so a bug cannot "re-baseline" corrupt bytes as healthy.
        static::updating(function (MemoryPhoto $photo): void {
            if ($photo->getOriginal('status') === 'verified' && $photo->isDirty('checksum')) {
                throw new \LogicException('The checksum of a verified photo cannot change.');
            }
        });
    }

    /** Without these the ciphertext can never be decrypted, however many copies exist. */
    public const DECRYPTION_METADATA = ['checksum', 'encryption_version', 'key_id', 'nonce', 'mac'];

    /**
     * Derived, never stored or client-settable. See docs/storage/reliability.md §10.
     * `protected` = verified primary + verified independent backup + complete
     * decryption metadata, all found via the same storage_key.
     */
    public function protectionStatus(): string
    {
        if ($this->trashed() || $this->isPurged()) {
            return 'deleted';
        }

        if ($this->status !== 'verified') {
            return $this->status === 'failed' ? 'failed' : 'pending_upload';
        }

        if (! $this->hasDecryptionMetadata()) {
            return 'degraded';
        }

        // A copy that failed its last re-hash no longer counts, whatever the backup job said.
        foreach ([$this->primary_integrity, $this->backup_integrity] as $integrity) {
            if (in_array($integrity, ['mismatch', 'missing'], true)) {
                return $this->repair_status === 'pending' ? 'restoring' : 'degraded';
            }
        }

        return match ($this->backup_status) {
            'verified' => 'protected',
            'failed' => 'degraded',
            default => 'backup_pending',
        };
    }

    /**
     * protectionStatus() as a SQL expression, for counting without loading rows.
     * Kept in lockstep with the PHP version by MemoryPhotoProtectionStatusTest.
     */
    public static function protectionStatusSql(): string
    {
        $missingMetadata = collect(self::DECRYPTION_METADATA)
            ->map(fn (string $column) => "NULLIF({$column}, '') IS NULL")
            ->implode(' OR ');

        return <<<SQL
            CASE
                WHEN deleted_at IS NOT NULL OR primary_purged_at IS NOT NULL THEN 'deleted'
                WHEN status <> 'verified' THEN CASE WHEN status = 'failed' THEN 'failed' ELSE 'pending_upload' END
                WHEN {$missingMetadata} THEN 'degraded'
                WHEN primary_integrity IN ('mismatch', 'missing') OR backup_integrity IN ('mismatch', 'missing')
                    THEN CASE WHEN repair_status = 'pending' THEN 'restoring' ELSE 'degraded' END
                WHEN backup_status = 'verified' THEN 'protected'
                WHEN backup_status = 'failed' THEN 'degraded'
                ELSE 'backup_pending'
            END
            SQL;
    }

    /** @return array<string, int> protection status => count */
    public static function protectionCounts($query): array
    {
        return $query
            ->withTrashed()
            ->toBase()
            ->selectRaw(self::protectionStatusSql().' AS protection, COUNT(*) AS total')
            ->groupBy('protection')
            ->pluck('total', 'protection')
            ->map(fn ($total) => (int) $total)
            ->all();
    }

    public function memory(): BelongsTo
    {
        return $this->belongsTo(
            Memory::class
        );
    }

    public function uploadedBy(): BelongsTo
    {
        return $this->belongsTo(
            User::class,
            'uploaded_by'
        );
    }

    public function hasDecryptionMetadata(): bool
    {
        foreach (self::DECRYPTION_METADATA as $column) {
            if (blank($this->{$column})) {
                return false;
            }
        }

        return true;
    }
}
