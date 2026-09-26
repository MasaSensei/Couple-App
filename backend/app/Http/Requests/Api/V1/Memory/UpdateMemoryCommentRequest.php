<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;

class UpdateMemoryCommentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'body' => [
                'required',
                'string',
                'max:5000',
            ],
        ];
    }
}
