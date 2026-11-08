<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** An entitlement key the backend knows how to enforce (see EntitlementCatalog). */
class EntitlementDefinition extends Model
{
    protected $fillable = ['name', 'description', 'sort_order'];

    protected function casts(): array
    {
        return [
            'default_value' => 'json',
            'sort_order' => 'integer',
        ];
    }
}
