<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;

class CreateMemoryPhotoUploadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'original_filename' => [
                'nullable',
                'string',
                'max:255',
            ],

            'mime_type' => [
                'required',
                'string',
                'in:image/jpeg,image/png,image/webp',
            ],

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
        ];
    }
}
