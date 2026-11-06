<?php

namespace App\Http\Resources\Api\V1\Memory;

use App\Services\Memory\MemoryProtectionService;
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

            'original_filename' => $this->original_filename,
            'mime_type' => $this->mime_type,
            'file_size' => $this->file_size,
            'width' => $this->width,
            'height' => $this->height,

            'checksum' => $this->checksum,
            'sort_order' => $this->sort_order,
            'status' => $this->status,
            // Server-derived; see MemoryProtectionService::USER_STATUS.
            'protection_status' => MemoryProtectionService::userStatus($this->resource),

            'encryption_version' => $this->encryption_version,
            'encryption_algorithm' => $this->encryption_algorithm,
            'key_id' => $this->key_id,
            'nonce' => $this->nonce,
            'mac' => $this->mac,
            'encrypted_size' => $this->encrypted_size,

            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
            'deleted_at' => $this->deleted_at?->toISOString(),
            'restorable_until' => $this->deleted_at ? $this->restorableUntil()->toISOString() : null,
        ];
    }
}
