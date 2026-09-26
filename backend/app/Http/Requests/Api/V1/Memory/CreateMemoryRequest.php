<?php

namespace App\Http\Requests\Api\V1\Memory;

use Illuminate\Foundation\Http\FormRequest;

class CreateMemoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
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

            'memory_date' => [
                'required',
                'date',
            ],

            'location_name' => [
                'nullable',
                'string',
                'max:255',
            ],

            'location_address' => [
                'nullable',
                'string',
                'max:500',
            ],

            'latitude' => [
                'nullable',
                'numeric',
                'between:-90,90',
            ],

            'longitude' => [
                'nullable',
                'numeric',
                'between:-180,180',
            ],

            'date_id' => [
                'nullable',
                'integer',
                'exists:dates,id',
            ],
        ];
    }
}
