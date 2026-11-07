<?php

namespace App\Http\Requests\Api\V1\Billing;

use App\Services\Billing\Providers\PaymentProviderRegistry;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CreatePurchaseIntentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        // Only identifiers: price, period and status are never accepted from the app.
        return [
            'plan_key' => ['required', 'string', 'max:64'],
            'provider' => ['required', 'string', Rule::in(PaymentProviderRegistry::KEYS)],
        ];
    }
}
