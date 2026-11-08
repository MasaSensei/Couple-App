<?php

namespace App\Filament\Resources\SubscriptionPlans\RelationManagers;

use App\Filament\BillingAccess;
use App\Filament\Support\StatusColors;
use App\Models\SubscriptionPlanVersion;
use App\Services\Billing\EntitlementCatalog;
use App\Services\Billing\PlanManagement;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Notifications\Notification;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Validation\ValidationException;
use LogicException;
use RuntimeException;

/**
 * Price / interval / quota / entitlements, versioned. Drafts can be created,
 * published or deleted; published versions are read-only (the model refuses
 * edits), so existing subscribers are never affected by a change here.
 */
class VersionsRelationManager extends RelationManager
{
    protected static string $relationship = 'versions';

    public function isReadOnly(): bool
    {
        return false;
    }

    public function table(Table $table): Table
    {
        return $table
            ->defaultSort('version', 'desc')
            ->columns([
                TextColumn::make('version'),
                TextColumn::make('status')->badge()
                    ->color(fn (?string $state) => StatusColors::for($state))->formatStateUsing(fn (?string $state) => StatusColors::label($state)),
                TextColumn::make('price_amount')->label('Price (minor units)')->numeric(),
                TextColumn::make('currency'),
                TextColumn::make('billing_interval')->label('Interval')
                    ->formatStateUsing(fn (string $state, SubscriptionPlanVersion $record) => $state === 'none' ? 'none' : "{$record->billing_interval_count} {$state}"),
                TextColumn::make('storage')->label('Storage')
                    ->state(fn (SubscriptionPlanVersion $record) => round(($record->entitlements['storage_limit_bytes'] ?? 0) / EntitlementCatalog::GIB, 2).' GiB'),
                TextColumn::make('entitlements')->label('Entitlements')
                    ->state(fn (SubscriptionPlanVersion $record) => collect($record->entitlements)->except('storage_limit_bytes')->filter()->keys()->implode(', ') ?: '–'),
                TextColumn::make('provider_products')->label('Store products')
                    ->state(fn (SubscriptionPlanVersion $record) => collect($record->provider_products)->map(fn ($id, $p) => "{$p}: {$id}")->implode(', ') ?: '–'),
                TextColumn::make('published_at')->dateTime()->placeholder('–'),
            ])
            ->headerActions([
                Action::make('draft')
                    ->label('New draft version')
                    ->visible(fn () => BillingAccess::can('plans.manage'))
                    ->fillForm(fn () => $this->defaults())
                    ->schema([
                        TextInput::make('price_amount')->label('Price in minor units (IDR has none: 29000 = Rp 29.000)')->numeric()->minValue(0)->required(),
                        TextInput::make('currency')->length(3)->required(),
                        Select::make('billing_interval')->options(['none' => 'none (Free only)', 'month' => 'month', 'year' => 'year'])->required(),
                        TextInput::make('billing_interval_count')->numeric()->minValue(1)->maxValue(12)->required(),
                        TextInput::make('storage_gib')->label('Storage quota (GiB)')->numeric()->minValue(0)->required(),
                        Toggle::make('premium_themes'),
                        Toggle::make('premium_photo_booth'),
                        TextInput::make('product_mock')->label('Mock product id (dev only)'),
                        TextInput::make('product_google_play')->label('Google Play product id'),
                        TextInput::make('product_app_store')->label('App Store product id'),
                    ])
                    ->action(function (array $data): void {
                        $this->run(fn () => app(PlanManagement::class)->createDraft($this->getOwnerRecord(), auth()->user(), [
                            'price_amount' => (int) $data['price_amount'],
                            'currency' => strtoupper($data['currency']),
                            'billing_interval' => $data['billing_interval'],
                            'billing_interval_count' => (int) $data['billing_interval_count'],
                            'entitlements' => [
                                'storage_limit_bytes' => (int) round(((float) $data['storage_gib']) * EntitlementCatalog::GIB),
                                'premium_themes' => (bool) $data['premium_themes'],
                                'premium_photo_booth' => (bool) $data['premium_photo_booth'],
                            ],
                            'provider_products' => array_filter([
                                'mock' => $data['product_mock'] ?? null,
                                'google_play' => $data['product_google_play'] ?? null,
                                'app_store' => $data['product_app_store'] ?? null,
                            ]),
                        ]), 'Draft created');
                    }),
            ])
            ->recordActions([
                Action::make('publish')
                    ->requiresConfirmation()
                    ->modalDescription('The current published version is archived. Existing subscribers keep the version they bought; new purchases get this one.')
                    ->visible(fn (SubscriptionPlanVersion $record) => $record->status === 'draft' && BillingAccess::can('plans.manage'))
                    ->action(fn (SubscriptionPlanVersion $record) => $this->run(fn () => app(PlanManagement::class)->publish($record, auth()->user()), 'Published')),
                Action::make('deleteDraft')
                    ->label('Delete draft')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->visible(fn (SubscriptionPlanVersion $record) => $record->status === 'draft' && BillingAccess::can('plans.manage'))
                    ->action(fn (SubscriptionPlanVersion $record) => $this->run(fn () => app(PlanManagement::class)->deleteDraft($record, auth()->user()), 'Draft deleted')),
            ]);
    }

    private function defaults(): array
    {
        $base = $this->getOwnerRecord()->versions()->orderByDesc('version')->first();

        return [
            'price_amount' => $base?->price_amount ?? 0,
            'currency' => $base?->currency ?? 'IDR',
            'billing_interval' => $base?->billing_interval ?? 'month',
            'billing_interval_count' => $base?->billing_interval_count ?? 1,
            'storage_gib' => round(($base?->entitlements['storage_limit_bytes'] ?? EntitlementCatalog::GIB) / EntitlementCatalog::GIB, 2),
            'premium_themes' => (bool) ($base?->entitlements['premium_themes'] ?? false),
            'premium_photo_booth' => (bool) ($base?->entitlements['premium_photo_booth'] ?? false),
            'product_mock' => $base?->provider_products['mock'] ?? null,
            'product_google_play' => $base?->provider_products['google_play'] ?? null,
            'product_app_store' => $base?->provider_products['app_store'] ?? null,
        ];
    }

    private function run(callable $operation, string $success): void
    {
        try {
            $operation();
            Notification::make()->title($success)->success()->send();
        } catch (ValidationException $exception) {
            Notification::make()->title(collect($exception->errors())->flatten()->implode(' '))->danger()->send();
        } catch (RuntimeException|LogicException|AuthorizationException $exception) {
            Notification::make()->title($exception->getMessage())->danger()->send();
        }
    }
}
