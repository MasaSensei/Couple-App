<?php

namespace App\Filament\Support;

/**
 * One place for status → badge colour, so the same word has the same colour
 * on every admin screen. Colours are the panel's semantic palette:
 * success (healthy/done), info (in progress), warning (needs a look),
 * danger (broken/action needed), gray (inactive/neutral).
 */
final class StatusColors
{
    private const MAP = [
        // Generic results
        'succeeded' => 'success',
        'processed' => 'success',
        'passed' => 'success',
        'verified' => 'success',
        'failed' => 'danger',
        'skipped' => 'gray',
        'ignored' => 'gray',
        'queued' => 'info',
        'pending' => 'info',

        // Catalog items (themes, templates, plan versions)
        'active' => 'success',
        'published' => 'success',
        'hidden' => 'warning',
        'draft' => 'warning',
        'retired' => 'gray',

        // Subscriptions
        'grace_period' => 'warning',
        'cancelled' => 'warning',
        'payment_failed' => 'danger',
        'suspended' => 'danger',
        'expired' => 'gray',

        // Photo protection (never "protected" without a verified backup)
        'protected' => 'success',
        'backup_pending' => 'info',
        'restoring' => 'warning',
        'pending_upload' => 'gray',
        'degraded' => 'danger',
        'deleted' => 'gray',
    ];

    public static function for(?string $status): string
    {
        return self::MAP[$status] ?? 'gray';
    }

    /** "grace_period" → "Grace period" for badge labels. */
    public static function label(?string $status): string
    {
        return $status === null ? '–' : ucfirst(str_replace('_', ' ', $status));
    }

    /** @return list<string> */
    public static function known(): array
    {
        return array_keys(self::MAP);
    }
}
