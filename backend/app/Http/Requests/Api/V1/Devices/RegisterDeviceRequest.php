<?php

namespace App\Http\Requests\Api\V1\Devices;

use Illuminate\Foundation\Http\FormRequest;

class RegisterDeviceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'device_identifier' => [
                'required',
                'string',
                'max:128',
            ],
            'device_name' => [
                'nullable',
                'string',
                'max:255',
            ],
            'platform' => [
                'required',
                'in:android,ios',
            ],
            'public_key' => [
                'required',
                'string',
                'base64',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    $decoded = base64_decode($value, true);

                    if ($decoded === false || strlen($decoded) !== 32) {
                        $fail('The public key must contain exactly 32 bytes.');
                    }
                },
            ],
        ];
    }
}
