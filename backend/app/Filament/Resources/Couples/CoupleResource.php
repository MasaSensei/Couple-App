<?php

namespace App\Filament\Resources\Couples;

use App\Filament\Resources\Couples\Pages\ListCouples;
use App\Filament\Resources\Couples\Pages\ViewCouple;
use App\Filament\Resources\Couples\RelationManagers\MembersRelationManager;
use App\Filament\Resources\Couples\Schemas\CoupleInfolist;
use App\Filament\Resources\Couples\Tables\CouplesTable;
use App\Models\Couple;
use App\Providers\Filament\AdminPanelProvider;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

class CoupleResource extends Resource
{
    protected static ?string $model = Couple::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUserGroup;

    protected static string|UnitEnum|null $navigationGroup = AdminPanelProvider::GROUP_PEOPLE;

    protected static ?string $navigationLabel = 'Couples';

    protected static ?int $navigationSort = 20;

    protected static ?string $recordTitleAttribute = 'id';

    public static function getRecordTitle(?Model $record): string
    {
        return $record === null ? 'Couple' : "Couple #{$record->getKey()}";
    }

    public static function infolist(Schema $schema): Schema
    {
        return CoupleInfolist::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return CouplesTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            MembersRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListCouples::route('/'),
            'view' => ViewCouple::route('/{record}'),
        ];
    }

    public static function canView(Model $record): bool
    {
        return auth()->user()?->is_admin === true;
    }
}
