<?php

namespace App\Http\Requests\Api\V1\Billing;

use App\Services\Billing\Providers\PaymentProviderRegistry;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class VerifyPurchaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        // Anything else the app sends (status, amount, expiry...) is ignored:
        // validated() only returns these keys.
        return [
            'provider' => ['required', 'string', Rule::in(PaymentProviderRegistry::KEYS)],
            'product_id' => ['required', 'string', 'max:255'],
            'purchase_token' => ['required', 'string', 'max:4096'],
        ];
    }
}
