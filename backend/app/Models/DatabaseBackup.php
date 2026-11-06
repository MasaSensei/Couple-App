<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Bookkeeping for db:backup / db:restore-check. Holds no keys and no dump content. */
class DatabaseBackup extends Model
{
    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'table_counts' => 'array',
            'size_bytes' => 'integer',
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
            'restore_checked_at' => 'datetime',
        ];
    }

    public static function latestSucceeded(): ?self
    {
        return static::where('status', 'succeeded')->latest('finished_at')->latest('id')->first();
    }
}
