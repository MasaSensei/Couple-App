<?php

namespace App\Http\Requests\Api\V1\Appearance;

use Illuminate\Foundation\Http\FormRequest;

class UpdateCoupleThemeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'theme_key' => ['required', 'string', 'max:64'],
            // Values are checked against the theme's presets by AppearanceCatalog.
            'customization' => ['present', 'array', 'max:10'],
            'version' => ['required', 'integer', 'min:0'],
        ];
    }
}
