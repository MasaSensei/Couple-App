<?php

namespace App\Http\Resources\Api\V1\Memory;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MemoryCommentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'memory_id' => $this->memory_id,
            'user' => [
                'id' => $this->user->id,
                'name' => $this->user->name,
            ],
            'body' => $this->body,
            'created_at' =>
            $this->created_at?->toISOString(),
            'updated_at' =>
            $this->updated_at?->toISOString(),
        ];
    }
}
