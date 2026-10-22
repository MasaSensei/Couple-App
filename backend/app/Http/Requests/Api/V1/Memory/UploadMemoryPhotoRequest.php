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
        // The body is an encrypted blob; it is never parsed as an image.
        return [
            'photo' => [
                'required',
                'file',
                'max:20480',
            ],
        ];
    }
}
