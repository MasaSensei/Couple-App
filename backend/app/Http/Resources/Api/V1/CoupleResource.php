<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CoupleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,

            'invite_code' => $this->invite_code,

            'members' => $this->members
                ->map(function ($member) {
                    return [
                        'id' => $member->user->id,
                        'name' => $member->user->name,
                        'email' => $member->user->email,
                    ];
                })
                ->values()
                ->all(),

            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
