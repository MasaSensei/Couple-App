<?php

namespace App\Http\Resources\Api\V1\Couple;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CoupleKeyPackageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'device_id' => $this->device_id,
            'key_id' => $this->key_id,
            'encryption_version' => $this->encryption_version,
            'ephemeral_public_key' => $this->ephemeral_public_key,
            'nonce' => $this->nonce,
            'ciphertext' => $this->ciphertext,
            'mac' => $this->mac,
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
            'revoked_at' => $this->revoked_at?->toISOString(),
        ];
    }
}
