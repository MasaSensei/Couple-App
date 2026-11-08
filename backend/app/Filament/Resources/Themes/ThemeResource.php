<?php

namespace App\Filament\Resources\Themes;

use App\Filament\Resources\Themes\Pages\EditTheme;
use App\Filament\Resources\Themes\Pages\ListThemes;
use App\Filament\Support\StatusColors;
use App\Models\CoupleThemeSetting;
use App\Models\Theme;
use App\Providers\Filament\AdminPanelProvider;
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
 * Theme catalog. Catalog metadata only: keys, versions and
 * visuals come from the app (appearance:sync-catalog). Admins control
 * availability, premium flag and order. Nothing here touches user photos.
 */
class ThemeResource extends Resource
{
    protected static ?string $model = Theme::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedSwatch;

    protected static string|UnitEnum|null $navigationGroup = AdminPanelProvider::GROUP_APPEARANCE;

    protected static ?int $navigationSort = 10;

    protected static ?string $navigationLabel = 'Themes';

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
                TextColumn::make('couples')
                    ->label('Couples using')
                    ->state(fn ($record) => CoupleThemeSetting::where('theme_key', $record->key)->count()),
                TextColumn::make('status')->badge()
                    ->color(fn (?string $state) => StatusColors::for($state))->formatStateUsing(fn (?string $state) => StatusColors::label($state)),
                IconColumn::make('is_premium')->boolean()->label('Premium'),
                TextColumn::make('sort_order')->sortable(),
                TextColumn::make('updated_at')->since(),
            ])
            ->recordActions([EditAction::make()]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListThemes::route('/'),
            'edit' => EditTheme::route('/{record}/edit'),
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
