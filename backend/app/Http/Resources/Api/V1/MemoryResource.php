<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MemoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,

            'couple_id' => $this->couple_id,

            'created_by' => $this->created_by,

            'date_id' => $this->date_id,

            'title' => $this->title,

            'description' => $this->description,

            'memory_date' => $this->memory_date?->format('Y-m-d'),

            'location_name' => $this->location_name,

            'location_address' => $this->location_address,

            'latitude' => $this->latitude,

            'longitude' => $this->longitude,

            'created_at' => $this->created_at?->toISOString(),

            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
