<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

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
        ];
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
        if ($this->trashed()) {
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
