<?php

namespace App\Filament\Resources\MemoryPhotos;

use App\Filament\Resources\MemoryPhotos\Pages\ListMemoryPhotos;
use App\Filament\Resources\MemoryPhotos\Tables\MemoryPhotosTable;
use App\Models\MemoryPhoto;
use App\Providers\Filament\AdminPanelProvider;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/**
 * Storage metadata only. Deliberately has no view/preview/download page and
 * never touches ciphertext: admins cannot see photo content (Phase 5).
 */
class MemoryPhotoResource extends Resource
{
    protected static ?string $model = MemoryPhoto::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedServerStack;

    protected static string|UnitEnum|null $navigationGroup = AdminPanelProvider::GROUP_STORAGE;

    protected static ?int $navigationSort = 10;

    protected static ?string $navigationLabel = 'Photo storage';

    public static function table(Table $table): Table
    {
        return MemoryPhotosTable::configure($table);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->withTrashed()->with('memory:id,couple_id');
    }

    public static function getPages(): array
    {
        return [
            'index' => ListMemoryPhotos::route('/'),
        ];
    }

    public static function canViewAny(): bool
    {
        return auth()->user()?->is_admin === true;
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
