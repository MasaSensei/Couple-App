<?php

namespace App\Filament\Resources\PaymentWebhookEvents;

use App\Filament\BillingAccess;
use App\Filament\Resources\PaymentWebhookEvents\Pages\ListPaymentWebhookEvents;
use App\Filament\Support\StatusColors;
use App\Models\PaymentWebhookEvent;
use App\Providers\Filament\AdminPanelProvider;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/** Read-only webhook log (billing.view). The raw payload is never shown. */
class PaymentWebhookEventResource extends Resource
{
    protected static ?string $model = PaymentWebhookEvent::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBolt;

    protected static string|UnitEnum|null $navigationGroup = AdminPanelProvider::GROUP_BILLING;

    protected static ?int $navigationSort = 40;

    protected static ?string $navigationLabel = 'Payment webhooks';

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('id'),
                TextColumn::make('provider'),
                TextColumn::make('event_type')->label('Type'),
                TextColumn::make('status')->badge()
                    ->color(fn (?string $state) => StatusColors::for($state))->formatStateUsing(fn (?string $state) => StatusColors::label($state)),
                TextColumn::make('attempts'),
                TextColumn::make('error')->limit(60)->placeholder('–'),
                TextColumn::make('occurred_at')->dateTime()->placeholder('–'),
                TextColumn::make('created_at')->label('Received')->since(),
            ])
            ->filters([
                SelectFilter::make('status')->options(['received' => 'received', 'processed' => 'processed', 'ignored' => 'ignored', 'failed' => 'failed']),
            ]);
    }

    public static function getPages(): array
    {
        return ['index' => ListPaymentWebhookEvents::route('/')];
    }

    public static function canViewAny(): bool
    {
        return BillingAccess::can('billing.view');
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit(Model $record): bool
    {
        return false;
    }

    public static function canDelete(Model $record): bool
    {
        return false;
    }
}
