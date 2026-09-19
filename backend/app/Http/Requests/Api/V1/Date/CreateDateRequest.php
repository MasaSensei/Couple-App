<?php

namespace App\Http\Requests\Api\V1\Date;

use Illuminate\Foundation\Http\FormRequest;

class CreateDateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => [
                'required',
                'string',
                'max:150',
            ],

            'description' => [
                'nullable',
                'string',
            ],

            'location' => [
                'nullable',
                'string',
                'max:255',
            ],

            'scheduled_at' => [
                'required',
                'date',
            ],
        ];
    }
}
