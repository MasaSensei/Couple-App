<?php

namespace App\Http\Requests\Api\V1\Billing;

use App\Services\Billing\Providers\PaymentProviderRegistry;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RestorePurchasesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'provider' => ['required', 'string', Rule::in(PaymentProviderRegistry::KEYS)],
            'purchases' => ['required', 'array', 'min:1', 'max:10'],
            'purchases.*.product_id' => ['required', 'string', 'max:255'],
            'purchases.*.purchase_token' => ['required', 'string', 'max:4096'],
        ];
    }
}
