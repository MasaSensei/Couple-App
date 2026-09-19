<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DateResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'couple_id' => $this->couple_id,
            'created_by' => $this->created_by,

            'title' => $this->title,
            'description' => $this->description,
            'location' => $this->location,

            'scheduled_at' =>
            $this->scheduled_at?->toISOString(),

            'status' => $this->status,

            'completed_at' =>
            $this->completed_at?->toISOString(),

            'created_at' =>
            $this->created_at?->toISOString(),

            'updated_at' =>
            $this->updated_at?->toISOString(),
        ];
    }
}
