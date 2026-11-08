<?php

namespace App\Filament;

use Closure;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Illuminate\Auth\Access\AuthorizationException;
use LogicException;
use RuntimeException;

/**
 * Permission checks for billing screens. Being an admin is not enough:
 * billing.view / billing.manage / plans.manage must be granted explicitly
 * (php artisan admin:permission grant <email> <permission>).
 */
final class BillingAccess
{
    public static function can(string $permission): bool
    {
        return auth()->user()?->hasAdminPermission($permission) === true;
    }

    /** A confirmed action with a mandatory audit reason. */
    public static function auditedAction(string $name, string $label, Closure $run, array $extraFields = []): Action
    {
        return Action::make($name)
            ->label($label)
            ->requiresConfirmation()
            ->visible(fn () => self::can('billing.manage'))
            ->schema([
                ...$extraFields,
                Textarea::make('reason')->label('Reason (stored in the audit log)')->required()->minLength(5)->maxLength(500),
            ])
            ->action(function (array $data, $record = null) use ($run, $label): void {
                try {
                    $run($data, $record, auth()->user());
                    Notification::make()->title("{$label}: done")->success()->send();
                } catch (AuthorizationException|RuntimeException|LogicException $exception) {
                    Notification::make()->title($exception->getMessage())->danger()->send();
                }
            });
    }
}
