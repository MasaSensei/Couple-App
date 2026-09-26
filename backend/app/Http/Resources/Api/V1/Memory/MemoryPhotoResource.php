<?php

namespace App\Http\Resources\Api\V1\Memory;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MemoryPhotoResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'memory_id' => $this->memory_id,
            'uploaded_by' => $this->uploaded_by,

            'original_filename' =>
            $this->original_filename,

            'mime_type' => $this->mime_type,
            'file_size' => $this->file_size,
            'width' => $this->width,
            'height' => $this->height,

            'status' => $this->status,
            'sort_order' => $this->sort_order,

            'created_at' =>
            $this->created_at?->toISOString(),

            'updated_at' =>
            $this->updated_at?->toISOString(),
        ];
    }
}
