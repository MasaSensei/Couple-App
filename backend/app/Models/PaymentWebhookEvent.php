<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A signature-verified provider notification. (provider, event_id) is unique. */
class PaymentWebhookEvent extends Model
{
    protected $guarded = ['*'];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'attempts' => 'integer',
            'occurred_at' => 'datetime',
            'processed_at' => 'datetime',
        ];
    }
}
