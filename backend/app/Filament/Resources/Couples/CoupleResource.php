<?php

namespace App\Filament\Resources\Couples;

use App\Filament\Resources\Couples\Pages\ListCouples;
use App\Filament\Resources\Couples\Pages\ViewCouple;
use App\Filament\Resources\Couples\Schemas\CoupleInfolist;
use App\Filament\Resources\Couples\Tables\CouplesTable;
use App\Models\Couple;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;

class CoupleResource extends Resource
{
    protected static ?string $model = Couple::class;

    protected static string|BackedEnum|null $navigationIcon =
    Heroicon::OutlinedRectangleStack;

    protected static ?string $recordTitleAttribute = 'id';

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
            \App\Filament\Resources\Couples\RelationManagers\MembersRelationManager::class,
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
