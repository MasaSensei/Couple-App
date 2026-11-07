<?php

namespace App\Services\Billing;

use App\Jobs\ProcessPaymentWebhook;
use App\Models\PaymentWebhookEvent;
use App\Services\Billing\Providers\InvalidWebhookSignature;
use App\Services\Billing\Providers\PaymentProviderRegistry;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Entry point for provider webhooks.
 *
 *  1. Signature is verified first; an unverified body is never stored or applied.
 *  2. (provider, event_id) is inserted under a unique index: a duplicate
 *     delivery is acknowledged and dropped here.
 *  3. Processing is queued (ProcessPaymentWebhook), so the provider gets a
 *     fast 2xx and a slow/unavailable store API cannot cause timeouts.
 */
class WebhookReceiver
{
    public function __construct(
        private readonly PaymentProviderRegistry $providers,
    ) {}

    /** @return array{status: string, event_id?: int} */
    public function receive(string $providerKey, Request $request): array
    {
        $provider = $this->providers->get($providerKey);

        if ($provider === null) {
            throw new InvalidWebhookSignature('Unknown provider.');
        }

        try {
            $notification = $provider->parseWebhook($request);
        } catch (InvalidWebhookSignature $exception) {
            Log::channel('alerts')->warning('Rejected payment webhook with an invalid signature.', ['provider' => $providerKey]);

            throw $exception;
        }

        try {
            $event = DB::transaction(fn () => PaymentWebhookEvent::forceCreate([
                'provider' => $provider->key(),
                'event_id' => $notification->eventId,
                'event_type' => mb_substr($notification->type, 0, 64),
                'provider_subscription_id' => $notification->subscriptionId,
                'payload' => $notification->payload,
                'occurred_at' => $notification->occurredAt,
            ]));
        } catch (UniqueConstraintViolationException) {
            return ['status' => 'duplicate'];
        }

        try {
            ProcessPaymentWebhook::dispatch($event->id);
        } catch (\Throwable $exception) {
            // Stored as `received`; billing:retry-webhooks picks it up.
            report($exception);
        }

        return ['status' => 'accepted', 'event_id' => $event->id];
    }
}
