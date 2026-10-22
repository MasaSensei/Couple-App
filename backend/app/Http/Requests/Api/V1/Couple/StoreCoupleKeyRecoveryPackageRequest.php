<?php

namespace App\Http\Requests\Api\V1\Couple;

use Closure;
use Illuminate\Foundation\Http\FormRequest;

class StoreCoupleKeyRecoveryPackageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'key_id' => ['required', 'string', 'max:128'],
            'format_version' => ['required', 'integer', 'in:1'],
            'nonce' => ['required', 'string', $this->base64Bytes(12)],
            'ciphertext' => ['required', 'string', $this->base64Bytes(32)],
            'mac' => ['required', 'string', $this->base64Bytes(16)],
        ];
    }

    private function base64Bytes(int $length): Closure
    {
        return function (string $attribute, mixed $value, Closure $fail) use ($length): void {
            $decoded = is_string($value) ? base64_decode($value, true) : false;

            if ($decoded === false || strlen($decoded) !== $length) {
                $fail("The {$attribute} must contain exactly {$length} bytes.");
            }
        };
    }
}
