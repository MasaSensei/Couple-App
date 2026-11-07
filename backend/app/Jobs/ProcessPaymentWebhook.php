<?php

namespace App\Jobs;

use App\Models\PaymentWebhookEvent;
use App\Services\Billing\BillingException;
use App\Services\Billing\Providers\PaymentProviderRegistry;
use App\Services\Billing\Providers\PaymentProviderUnavailable;
use App\Services\Billing\Providers\PurchaseVerificationFailed;
use App\Services\Billing\SubscriptionService;
use App\Services\Billing\UnknownSubscription;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\DB;

/**
 * Applies one stored webhook. The notification is only a hint: the job
 * re-fetches the subscription from the provider and applies that, so the
 * outcome is the same however often or late the event arrives.
 */
class ProcessPaymentWebhook implements ShouldQueue
{
    use Queueable;

    public int $tries = 5;

    // Provider re-fetch is an HTTP call; must finish well inside retry_after (90 s).
    public int $timeout = 60;

    public function __construct(public readonly int $eventId) {}

    public function backoff(): array
    {
        return [60, 300, 900, 3600];
    }

    public function handle(PaymentProviderRegistry $providers, SubscriptionService $subscriptions): void
    {
        // Atomic claim: one worker per event, processed events never run again.
        // A claim older than 10 minutes is a crashed worker and may be taken over.
        $claimed = PaymentWebhookEvent::whereKey($this->eventId)
            ->where(fn ($query) => $query
                ->whereIn('status', ['received', 'failed'])
                ->orWhere(fn ($query) => $query->where('status', 'processing')->where('updated_at', '<=', now()->subMinutes(10))))
            ->update(['status' => 'processing', 'attempts' => DB::raw('attempts + 1'), 'updated_at' => now()]);

        if ($claimed === 0) {
            return;
        }

        $event = PaymentWebhookEvent::findOrFail($this->eventId);
        $provider = $providers->get($event->provider);

        try {
            if ($provider === null || $event->provider_subscription_id === null) {
                $this->finish($event, 'ignored', 'No subscription in this notification.');

                return;
            }

            $state = $provider->fetchSubscription($event->provider_subscription_id);
            $subscriptions->applyProviderState($state, "provider:{$event->provider}");
            $this->finish($event, 'processed');
        } catch (UnknownSubscription|PurchaseVerificationFailed|BillingException $exception) {
            // Not ours / not linkable: kept for reconciliation, not retried.
            $this->finish($event, 'ignored', $exception->getMessage());
        } catch (PaymentProviderUnavailable $exception) {
            $this->finish($event, 'failed', $exception->getMessage(), processed: false);

            throw $exception; // queue retries with backoff; billing:retry-webhooks is the safety net
        }
    }

    private function finish(PaymentWebhookEvent $event, string $status, ?string $error = null, bool $processed = true): void
    {
        $event->forceFill([
            'status' => $status,
            'error' => $error ? mb_substr($error, 0, 500) : null,
            'processed_at' => $processed ? now() : null,
        ])->save();
    }
}
