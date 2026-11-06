<?php

namespace App\Filament\Resources\PhotoBoothTemplates;

use App\Filament\Resources\PhotoBoothTemplates\Pages\EditPhotoBoothTemplate;
use App\Filament\Resources\PhotoBoothTemplates\Pages\ListPhotoBoothTemplates;
use App\Models\PhotoBoothTemplate;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/**
 * Photo Booth template catalog. Catalog metadata only: keys, versions and
 * visuals come from the app (appearance:sync-catalog). Admins control
 * availability, premium flag and order. Nothing here touches user photos.
 */
class PhotoBoothTemplateResource extends Resource
{
    protected static ?string $model = PhotoBoothTemplate::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedPhoto;

    protected static string|UnitEnum|null $navigationGroup = 'Appearance';

    protected static ?string $navigationLabel = 'Photo Booth templates';

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')->required()->maxLength(100),
            Select::make('status')
                ->options(['active' => 'Active (selectable)', 'hidden' => 'Hidden (kept for couples using it)', 'retired' => 'Retired'])
                ->required(),
            Toggle::make('is_premium')->label('Premium (Phase 8)'),
            TextInput::make('sort_order')->numeric()->minValue(0)->required(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('sort_order')
            ->columns([
                TextColumn::make('key')->searchable(),
                TextColumn::make('name'),
                TextColumn::make('version'),
                TextColumn::make('photo_slots')->label('Photos'),
                TextColumn::make('status')->badge()
                    ->color(fn (string $state) => ['active' => 'success', 'hidden' => 'warning', 'retired' => 'gray'][$state] ?? 'gray'),
                IconColumn::make('is_premium')->boolean()->label('Premium'),
                TextColumn::make('sort_order')->sortable(),
                TextColumn::make('updated_at')->since(),
            ])
            ->recordActions([EditAction::make()]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListPhotoBoothTemplates::route('/'),
            'edit' => EditPhotoBoothTemplate::route('/{record}/edit'),
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

    public static function canDelete(Model $record): bool
    {
        return false;
    }
}
