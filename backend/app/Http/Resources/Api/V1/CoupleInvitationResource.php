<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CoupleInvitationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'couple_id' => $this->couple_id,
            'invited_by' => $this->invited_by,
            'status' => $this->status,
            'expires_at' => $this->expires_at?->toISOString(),
            'accepted_at' => $this->accepted_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
