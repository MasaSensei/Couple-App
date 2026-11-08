<?php

namespace App\Http\Requests\Api\V1\Appearance;

use Illuminate\Foundation\Http\FormRequest;

class ResetCoupleThemeCustomizationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'version' => ['required', 'integer', 'min:0'],
        ];
    }
}
