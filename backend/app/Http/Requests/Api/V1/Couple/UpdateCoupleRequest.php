<?php

namespace App\Http\Requests\Api\V1\Couple;

use Illuminate\Foundation\Http\FormRequest;

class UpdateCoupleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Null clears it. Not in the future; not before 1900.
            'relationship_started_at' => ['present', 'nullable', 'date_format:Y-m-d', 'after_or_equal:1900-01-01', 'before_or_equal:today'],
        ];
    }
}
