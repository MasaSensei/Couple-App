<?php

namespace App\Http\Requests\Api\V1\Date;

use Illuminate\Foundation\Http\FormRequest;

class CreateDateCommentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'content' => [
                'required',
                'string',
                'max:5000',
            ],
        ];
    }
}
