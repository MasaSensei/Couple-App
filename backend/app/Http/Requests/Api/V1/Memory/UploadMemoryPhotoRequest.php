<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UploadMemoryPhotoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'encryption_mode' => [
                'sometimes',
                'string',
                Rule::in(['plain', 'encrypted']),
            ],

            'photo' => [
                'required',
                'file',
                'max:20480',
                ...$this->isEncryptedUpload()
                    ? []
                    : ['image', 'mimes:jpg,jpeg,png,webp'],
            ],
        ];
    }

    private function isEncryptedUpload(): bool
    {
        return $this->input('encryption_mode') === 'encrypted';
    }
}
