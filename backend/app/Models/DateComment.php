<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DateComment extends Model
{
    use HasFactory;

    protected $fillable = [
        'date_id',
        'user_id',
        'content',
    ];

    public function date(): BelongsTo
    {
        return $this->belongsTo(Date::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
