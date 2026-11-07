<?php

namespace App\Filament\Resources\SubscriptionPlans;

use App\Filament\BillingAccess;
use App\Filament\Resources\SubscriptionPlans\Pages\CreateSubscriptionPlan;
use App\Filament\Resources\SubscriptionPlans\Pages\EditSubscriptionPlan;
use App\Filament\Resources\SubscriptionPlans\Pages\ListSubscriptionPlans;
use App\Filament\Resources\SubscriptionPlans\RelationManagers\VersionsRelationManager;
use App\Models\SubscriptionPlan;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/**
 * Plan catalog (needs plans.manage). The plan row holds what may change
 * freely (name, description, availability, order); price, interval, quota
 * and entitlements live on versions (relation manager below).
 */
class SubscriptionPlanResource extends Resource
{
    protected static ?string $model = SubscriptionPlan::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedTag;

    protected static string|UnitEnum|null $navigationGroup = 'Billing';

    protected static ?string $navigationLabel = 'Plans';

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('key')->required()->maxLength(64)->alphaDash()
                ->unique(ignoreRecord: true)
                ->disabled(fn (?SubscriptionPlan $record) => $record !== null)
                ->helperText('Stable id used by the app. Cannot change later.'),
            TextInput::make('name')->required()->maxLength(100),
            Textarea::make('description')->maxLength(1000),
            Select::make('status')->required()->default('hidden')->options([
                'active' => 'Active (offered when it has a published version)',
                'hidden' => 'Hidden (not offered; existing subscribers keep it)',
                'retired' => 'Retired',
            ]),
            TextInput::make('sort_order')->numeric()->minValue(0)->required()->default(0),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('sort_order')
            ->columns([
                TextColumn::make('key'),
                TextColumn::make('name'),
                IconColumn::make('is_free')->boolean()->label('Free'),
                TextColumn::make('status')->badge(),
                TextColumn::make('publishedVersion.version')->label('Published v.')->placeholder('none'),
                TextColumn::make('publishedVersion.price_amount')->label('Price')->numeric()->placeholder('–'),
                TextColumn::make('publishedVersion.currency')->label('Cur.')->placeholder('–'),
                TextColumn::make('publishedVersion.billing_interval')->label('Interval')->placeholder('–'),
                TextColumn::make('subscribers')->label('Live subscriptions')
                    ->state(fn (SubscriptionPlan $record) => \App\Models\CoupleSubscription::live()
                        ->whereHas('planVersion', fn ($q) => $q->where('subscription_plan_id', $record->id))->count()),
                TextColumn::make('sort_order'),
            ])
            ->recordActions([EditAction::make()]);
    }

    public static function getRelations(): array
    {
        return [VersionsRelationManager::class];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSubscriptionPlans::route('/'),
            'create' => CreateSubscriptionPlan::route('/create'),
            'edit' => EditSubscriptionPlan::route('/{record}/edit'),
        ];
    }

    public static function canViewAny(): bool
    {
        return BillingAccess::can('plans.manage');
    }

    public static function canCreate(): bool
    {
        return BillingAccess::can('plans.manage');
    }

    public static function canEdit(Model $record): bool
    {
        return BillingAccess::can('plans.manage');
    }

    public static function canDelete(Model $record): bool
    {
        return false; // retire instead; subscriptions reference plans forever
    }
}
