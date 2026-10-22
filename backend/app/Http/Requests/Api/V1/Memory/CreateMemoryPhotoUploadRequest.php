<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CreateMemoryPhotoUploadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            // MIME type foto asli sebelum dienkripsi.
            'mime_type' => [
                'required',
                'string',
                Rule::in([
                    'image/jpeg',
                    'image/png',
                    'image/webp',
                    'application/octet-stream',
                ]),
            ],

            // Ukuran foto asli sebelum dienkripsi.
            'file_size' => [
                'required',
                'integer',
                'min:1',
            ],

            'width' => [
                'nullable',
                'integer',
                'min:1',
            ],

            'height' => [
                'nullable',
                'integer',
                'min:1',
            ],

            'sort_order' => [
                'nullable',
                'integer',
                'min:0',
            ],

            'encryption_version' => [
                'nullable',
                'integer',
                'min:1',
            ],

            'encryption_algorithm' => [
                'nullable',
                'string',
                Rule::in(['AES-256-GCM']),
            ],

            'key_id' => [
                'nullable',
                'string',
                'max:128',
            ],

            // Nonce AES-GCM 12 byte, dikirim dalam Base64.
            'nonce' => [
                'nullable',
                'string',
                'max:64',
            ],

            // Ukuran ciphertext dalam byte.
            'encrypted_size' => [
                'nullable',
                'integer',
                'min:1',
            ],

            // SHA-256 ciphertext dalam format heksadesimal.
            'checksum' => [
                'nullable',
                'string',
                'regex:/\A[a-f0-9]{64}\z/i',
            ],
        ];
    }
}
