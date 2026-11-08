<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A couple's shared theme + customization. `version` is the optimistic lock. */
class CoupleThemeSetting extends Model
{
    // Written only by CoupleThemeService through guarded, versioned updates.
    protected $guarded = ['*'];

    protected function casts(): array
    {
        return [
            'customization' => 'array',
            'version' => 'integer',
            'theme_version' => 'integer',
        ];
    }

    public function couple(): BelongsTo
    {
        return $this->belongsTo(Couple::class);
    }
}
