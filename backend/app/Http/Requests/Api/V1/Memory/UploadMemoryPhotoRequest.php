<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;

class UploadMemoryPhotoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'photo' => [
                'required',
                'file',
                'image',
                'mimes:jpg,jpeg,png,webp',
                'max:20480',
            ],
        ];
    }
}
