<?php

namespace App\Filament\Resources\EntitlementDefinitions;

use App\Filament\BillingAccess;
use App\Filament\Resources\EntitlementDefinitions\Pages\EditEntitlementDefinition;
use App\Filament\Resources\EntitlementDefinitions\Pages\ListEntitlementDefinitions;
use App\Models\EntitlementDefinition;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/**
 * Entitlement keys come from code (each needs enforcement code), so admins
 * can only rename and describe them — that text is what users see in the
 * plan comparison.
 */
class EntitlementDefinitionResource extends Resource
{
    protected static ?string $model = EntitlementDefinition::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedKey;

    protected static string|UnitEnum|null $navigationGroup = 'Billing';

    protected static ?string $navigationLabel = 'Entitlements';

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')->required()->maxLength(100),
            Textarea::make('description')->maxLength(500),
            TextInput::make('sort_order')->numeric()->minValue(0)->required(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('sort_order')
            ->columns([
                TextColumn::make('key'),
                TextColumn::make('name'),
                TextColumn::make('type'),
                TextColumn::make('description')->limit(80),
            ])
            ->recordActions([EditAction::make()]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListEntitlementDefinitions::route('/'),
            'edit' => EditEntitlementDefinition::route('/{record}/edit'),
        ];
    }

    public static function canViewAny(): bool
    {
        return BillingAccess::can('plans.manage');
    }

    public static function canEdit(Model $record): bool
    {
        return BillingAccess::can('plans.manage');
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canDelete(Model $record): bool
    {
        return false;
    }
}
