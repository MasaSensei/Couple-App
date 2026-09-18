<?php

namespace App\Http\Requests\Api\V1\Couple;

use Illuminate\Foundation\Http\FormRequest;

class JoinCoupleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'invite_code' => [
                'required',
                'string',
                'size:8',
            ],
        ];
    }
}
