<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateMemoryPhotoEncryptionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'encryption_version' => [
                'required',
                'integer',
                'min:1',
            ],
            'encryption_algorithm' => [
                'required',
                'string',
                Rule::in(['AES-256-GCM']),
            ],
            'key_id' => [
                'required',
                'string',
                'max:128',
            ],
            // AES-GCM nonce: 12 bytes, Base64.
            'nonce' => [
                'required',
                'string',
                'size:16',
                'regex:/\A[A-Za-z0-9+\/]{16}\z/',
            ],
            'encrypted_size' => [
                'required',
                'integer',
                'min:1',
            ],
            'checksum' => [
                'required',
                'string',
                'regex:/\A[a-f0-9]{64}\z/i',
            ],
            'mac' => [
                'required',
                'string',
                'size:24',
                'regex:/\A[A-Za-z0-9+\/]{22}==\z/',
            ],
        ];
    }
}
