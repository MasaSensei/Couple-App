<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;

class UpdateMemoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
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

            'memory_date' => [
                'sometimes',
                'required',
                'date',
            ],

            'location_name' => [
                'sometimes',
                'nullable',
                'string',
                'max:255',
            ],

            'location_address' => [
                'sometimes',
                'nullable',
                'string',
                'max:500',
            ],

            'latitude' => [
                'sometimes',
                'nullable',
                'numeric',
                'between:-90,90',
            ],

            'longitude' => [
                'sometimes',
                'nullable',
                'numeric',
                'between:-180,180',
            ],

            'date_id' => [
                'sometimes',
                'nullable',
                'integer',
                'exists:dates,id',
            ],
        ];
    }
}
