<?php

namespace App\Filament\Resources\StorageAudits;

use App\Filament\Resources\StorageAudits\Pages\ListStorageAudits;
use App\Models\PhotoStorageAudit;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use UnitEnum;

/** Append-only trail: repairs, restores, purges, admin actions. Read-only here. */
class StorageAuditResource extends Resource
{
    protected static ?string $model = PhotoStorageAudit::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedClipboardDocumentList;

    protected static string|UnitEnum|null $navigationGroup = 'Storage';

    protected static ?string $navigationLabel = 'Storage audit log';

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('created_at')->dateTime()->sortable(),
                TextColumn::make('memory_photo_id')->label('Photo ID')->placeholder('–'),
                TextColumn::make('action'),
                TextColumn::make('result')->badge()
                    ->color(fn (string $state) => ['succeeded' => 'success', 'failed' => 'danger', 'skipped' => 'gray'][$state] ?? 'info'),
                TextColumn::make('actor'),
                TextColumn::make('detail')->limit(80)->placeholder('–'),
            ])
            ->filters([
                SelectFilter::make('action')->options(fn () => PhotoStorageAudit::query()->distinct()->orderBy('action')->pluck('action', 'action')->all()),
                SelectFilter::make('result')->options(['succeeded' => 'succeeded', 'failed' => 'failed', 'skipped' => 'skipped', 'queued' => 'queued']),
            ]);
    }

    public static function getPages(): array
    {
        return ['index' => ListStorageAudits::route('/')];
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
