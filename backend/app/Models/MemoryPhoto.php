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
        'encrypted_size',
        'status',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'file_size' => 'integer',
            'width' => 'integer',
            'height' => 'integer',
            'encrypted_size' => 'integer',
            'sort_order' => 'integer',
        ];
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
}
