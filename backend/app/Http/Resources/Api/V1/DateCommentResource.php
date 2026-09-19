<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DateCommentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'date_id' => $this->date_id,
            'user_id' => $this->user_id,
            'user' => [
                'id' => $this->user?->id,
                'name' => $this->user?->name,
            ],
            'content' => $this->content,
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
