<?php

namespace App\Http\Requests\Api\V1\Date;

use Illuminate\Foundation\Http\FormRequest;

class UpdateDateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => [
                'sometimes',
                'required',
                'string',
                'max:150',
            ],

            'description' => [
                'sometimes',
                'nullable',
                'string',
            ],

            'location' => [
                'sometimes',
                'nullable',
                'string',
                'max:255',
            ],

            'scheduled_at' => [
                'sometimes',
                'required',
                'date',
            ],
        ];
    }
}
