<?php

namespace App\Http\Requests\Api\V1\Couple;

use Illuminate\Foundation\Http\FormRequest;

class StoreCoupleKeyPackageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'device_id' => [
                'required',
                'integer',
            ],

            'key_id' => [
                'required',
                'string',
                'max:128',
            ],

            'encryption_version' => [
                'required',
                'integer',
                'min:1',
            ],

            'ephemeral_public_key' => [
                'required',
                'string',
                'base64',
                function (
                    string $attribute,
                    mixed $value,
                    \Closure $fail,
                ): void {
                    $decoded = base64_decode($value, true);

                    if (
                        $decoded === false ||
                        strlen($decoded) !== 32
                    ) {
                        $fail(
                            'The ephemeral public key must contain exactly 32 bytes.',
                        );
                    }
                },
            ],

            'nonce' => [
                'required',
                'string',
                'base64',
                function (
                    string $attribute,
                    mixed $value,
                    \Closure $fail,
                ): void {
                    $decoded = base64_decode($value, true);

                    if (
                        $decoded === false ||
                        strlen($decoded) !== 12
                    ) {
                        $fail(
                            'The nonce must contain exactly 12 bytes.',
                        );
                    }
                },
            ],

            'ciphertext' => [
                'required',
                'string',
                'base64',
                function (
                    string $attribute,
                    mixed $value,
                    \Closure $fail,
                ): void {
                    $decoded = base64_decode($value, true);

                    if (
                        $decoded === false ||
                        strlen($decoded) !== 32
                    ) {
                        $fail(
                            'The ciphertext must contain exactly 32 bytes.',
                        );
                    }
                },
            ],

            'mac' => [
                'required',
                'string',
                'base64',
                function (
                    string $attribute,
                    mixed $value,
                    \Closure $fail,
                ): void {
                    $decoded = base64_decode($value, true);

                    if (
                        $decoded === false ||
                        strlen($decoded) !== 16
                    ) {
                        $fail(
                            'The MAC must contain exactly 16 bytes.',
                        );
                    }
                },
            ],
        ];
    }
}
