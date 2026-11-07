<?php

namespace App\Filament\Resources\CoupleSubscriptions;

use App\Filament\BillingAccess;
use App\Filament\Resources\CoupleSubscriptions\Pages\ListCoupleSubscriptions;
use App\Filament\Resources\CoupleSubscriptions\Pages\ViewCoupleSubscription;
use App\Filament\Resources\CoupleSubscriptions\RelationManagers\EventsRelationManager;
use App\Filament\Resources\CoupleSubscriptions\RelationManagers\TransactionsRelationManager;
use App\Models\CoupleSubscription;
use App\Services\Billing\AdminSubscriptionActions;
use BackedEnum;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\TextInput;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/**
 * Subscription status and history. Needs billing.view; every change needs
 * billing.manage plus a reason. Shows ids, statuses and amounts only:
 * no purchase tokens, no member emails, nothing about photos.
 */
class CoupleSubscriptionResource extends Resource
{
    protected static ?string $model = CoupleSubscription::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCreditCard;

    protected static string|UnitEnum|null $navigationGroup = 'Billing';

    protected static ?string $navigationLabel = 'Subscriptions';

    public const STATUS_COLORS = [
        'active' => 'success', 'cancelled' => 'warning', 'grace_period' => 'warning',
        'payment_failed' => 'danger', 'suspended' => 'danger', 'pending' => 'gray', 'expired' => 'gray',
    ];

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('id')->sortable(),
                TextColumn::make('couple_id')->label('Couple ID')->searchable(),
                TextColumn::make('planVersion.plan.name')->label('Plan'),
                TextColumn::make('planVersion.version')->label('Plan v.'),
                TextColumn::make('status')->badge()->color(fn (string $state) => self::STATUS_COLORS[$state] ?? 'gray'),
                TextColumn::make('provider'),
                IconColumn::make('auto_renew')->boolean(),
                TextColumn::make('current_period_end')->label('Period end')->dateTime()->sortable(),
                TextColumn::make('ended_reason')->placeholder('–'),
                TextColumn::make('last_synced_at')->since()->placeholder('–'),
            ])
            ->filters([
                SelectFilter::make('status')->options(array_combine(CoupleSubscription::STATUSES, CoupleSubscription::STATUSES)),
                SelectFilter::make('provider')->options(['mock' => 'mock', 'google_play' => 'google_play', 'app_store' => 'app_store', 'manual' => 'manual']),
            ])
            ->recordActions([ViewAction::make()]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            TextEntry::make('id'),
            TextEntry::make('couple_id')->label('Couple ID'),
            TextEntry::make('planVersion.plan.name')->label('Plan'),
            TextEntry::make('planVersion.version')->label('Plan version'),
            TextEntry::make('status')->badge()->color(fn (string $state) => self::STATUS_COLORS[$state] ?? 'gray'),
            TextEntry::make('ended_reason')->placeholder('–'),
            TextEntry::make('provider'),
            TextEntry::make('purchased_by')->label('Purchaser user ID')->placeholder('support grant'),
            TextEntry::make('auto_renew')->label('Auto-renew')->formatStateUsing(fn ($state) => $state ? 'on' : 'off'),
            TextEntry::make('current_period_start')->dateTime()->placeholder('–'),
            TextEntry::make('current_period_end')->dateTime()->placeholder('–'),
            TextEntry::make('grace_ends_at')->dateTime()->placeholder('–'),
            TextEntry::make('cancelled_at')->dateTime()->placeholder('–'),
            TextEntry::make('ended_at')->dateTime()->placeholder('–'),
            TextEntry::make('admin_suspended')->label('Admin hold')->formatStateUsing(fn ($state) => $state ? 'yes' : 'no'),
            TextEntry::make('entitlements_snapshot')->label('Entitlements (frozen at purchase)')
                ->state(fn (CoupleSubscription $record) => json_encode($record->entitlements_snapshot)),
            TextEntry::make('last_synced_at')->dateTime()->placeholder('–'),
        ]);
    }

    /** Header actions for the view page. */
    public static function manageActions(): array
    {
        $actions = app(AdminSubscriptionActions::class);

        return [
            BillingAccess::auditedAction('suspend', 'Suspend benefits', fn ($data, $record, $admin) => $actions->suspend($record, $admin, $data['reason']))
                ->visible(fn (CoupleSubscription $record) => BillingAccess::can('billing.manage') && in_array($record->status, ['active', 'cancelled', 'grace_period'], true)),
            BillingAccess::auditedAction('reinstate', 'Reinstate', fn ($data, $record, $admin) => $actions->reinstate($record, $admin, $data['reason']))
                ->visible(fn (CoupleSubscription $record) => BillingAccess::can('billing.manage') && $record->status === 'suspended'),
            BillingAccess::auditedAction('extend', 'Extend grant', fn ($data, $record, $admin) => $actions->extend($record, (int) $data['days'], $admin, $data['reason']),
                [TextInput::make('days')->numeric()->minValue(1)->maxValue(366)->required()])
                ->visible(fn (CoupleSubscription $record) => BillingAccess::can('billing.manage') && $record->provider === 'manual' && $record->status === 'active'),
            BillingAccess::auditedAction('revoke', 'End grant now', fn ($data, $record, $admin) => $actions->revoke($record, $admin, $data['reason']))
                ->visible(fn (CoupleSubscription $record) => BillingAccess::can('billing.manage') && $record->provider === 'manual' && $record->status !== 'expired'),
            BillingAccess::auditedAction('resync', 'Resync from store', fn ($data, $record, $admin) => $actions->resync($record, $admin, $data['reason']))
                ->visible(fn (CoupleSubscription $record) => BillingAccess::can('billing.manage') && $record->provider !== 'manual'),
        ];
    }

    public static function getRelations(): array
    {
        return [EventsRelationManager::class, TransactionsRelationManager::class];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListCoupleSubscriptions::route('/'),
            'view' => ViewCoupleSubscription::route('/{record}'),
        ];
    }

    public static function canViewAny(): bool
    {
        return BillingAccess::can('billing.view');
    }

    public static function canView(Model $record): bool
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
