<?php

namespace App\Filament\Resources\DatabaseBackups;

use App\Filament\Resources\DatabaseBackups\Pages\ListDatabaseBackups;
use App\Models\DatabaseBackup;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use UnitEnum;

/** Read-only history of db:backup and db:restore-check. No download: dumps are encrypted for operators only. */
class DatabaseBackupResource extends Resource
{
    protected static ?string $model = DatabaseBackup::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCircleStack;

    protected static string|UnitEnum|null $navigationGroup = 'Storage';

    protected static ?string $navigationLabel = 'Database backups';

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('id')->sortable(),
                TextColumn::make('status')->badge()
                    ->color(fn (string $state) => ['succeeded' => 'success', 'failed' => 'danger'][$state] ?? 'gray'),
                TextColumn::make('started_at')->dateTime(),
                TextColumn::make('finished_at')->since()->placeholder('–'),
                TextColumn::make('size_bytes')->label('Size')->numeric()->suffix(' B'),
                TextColumn::make('sha256')->limit(16)->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('restore_result')->label('Restore check')->badge()->placeholder('never')
                    ->color(fn (?string $state) => ['passed' => 'success', 'failed' => 'danger'][$state] ?? 'gray'),
                TextColumn::make('restore_checked_at')->since()->placeholder('–'),
                TextColumn::make('restore_detail')->limit(60)->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('error')->limit(60)->placeholder('–'),
            ]);
    }

    public static function getPages(): array
    {
        return ['index' => ListDatabaseBackups::route('/')];
    }

    public static function canViewAny(): bool
    {
        return auth()->user()?->is_admin === true;
    }

    public static function canCreate(): bool
    {
        return false;
    }
}
