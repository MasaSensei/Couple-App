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
            'storage_key' => $this->storage_key,
            'original_filename' => $this->original_filename,
            'mime_type' => $this->mime_type,
            'file_size' => $this->file_size,
            'width' => $this->width,
            'height' => $this->height,
            'checksum' => $this->checksum,
            'sort_order' => $this->sort_order,
            'status' => $this->status,

            'encryption_version' => $this->encryption_version,
            'encryption_algorithm' => $this->encryption_algorithm,
            'key_id' => $this->key_id,
            'nonce' => $this->nonce,
            'encrypted_size' => $this->encrypted_size,

            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
            'deleted_at' => $this->deleted_at?->toISOString(),
        ];
    }
}
