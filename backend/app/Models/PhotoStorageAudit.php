<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Append-only. Never holds keys, credentials, signed URLs or plaintext. */
class PhotoStorageAudit extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'memory_photo_id',
        'action',
        'result',
        'actor',
        'detail',
    ];

    public static function record(?int $photoId, string $action, string $result, string $actor, ?string $detail = null): self
    {
        return static::create([
            'memory_photo_id' => $photoId,
            'action' => $action,
            'result' => $result,
            'actor' => $actor,
            'detail' => $detail === null ? null : mb_substr($detail, 0, 255),
        ]);
    }

    public function photo(): BelongsTo
    {
        return $this->belongsTo(MemoryPhoto::class, 'memory_photo_id')->withTrashed();
    }
}
