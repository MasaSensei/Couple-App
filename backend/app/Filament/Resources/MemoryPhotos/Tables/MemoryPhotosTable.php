<?php

namespace App\Filament\Resources\MemoryPhotos\Tables;

use App\Filament\Support\StatusColors;
use App\Models\MemoryPhoto;
use App\Services\Storage\StorageOperatorActions;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Number;
use RuntimeException;

class MemoryPhotosTable
{
    private const PROTECTION_STATES = [
        'protected', 'backup_pending', 'restoring', 'pending_upload', 'degraded', 'failed', 'deleted',
    ];

    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('id')->label('Photo')->prefix('#')->weight('semibold')->sortable()->searchable(),
                TextColumn::make('memory.couple_id')->label('Couple')->prefix('#'),
                TextColumn::make('protection')
                    ->label('Protection')
                    ->badge()
                    ->state(fn (MemoryPhoto $record) => $record->protectionStatus())
                    ->formatStateUsing(fn (string $state) => StatusColors::label($state))
                    ->color(fn (string $state) => StatusColors::for($state)),
                TextColumn::make('status')->label('Upload')->badge()
                    ->formatStateUsing(fn (?string $state) => StatusColors::label($state))
                    ->color(fn (?string $state) => StatusColors::for($state)),
                TextColumn::make('backup_status')->label('Backup')->badge()->placeholder('–')
                    ->formatStateUsing(fn (?string $state) => StatusColors::label($state))
                    ->color(fn (?string $state) => StatusColors::for($state)),
                TextColumn::make('encrypted_size')->label('Size')
                    ->formatStateUsing(fn ($state) => $state === null ? '–' : Number::fileSize((int) $state))
                    ->alignEnd()
                    ->sortable(),
                TextColumn::make('integrity_checked_at')->label('Last check')->since()->dateTimeTooltip()->placeholder('never')->sortable(),

                // Diagnostics, hidden by default to keep the list readable.
                TextColumn::make('memory_id')->label('Memory')->prefix('#')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('primary_integrity')->label('Primary check')->placeholder('–')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('backup_integrity')->label('Backup check')->placeholder('–')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('repair_status')->label('Repair')->placeholder('–')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('encryption_version')->label('Enc. version')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('key_id')->label('Key ID')->limit(12)->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('checksum')->label('Checksum (SHA-256 of ciphertext)')->limit(16)->toggleable(isToggledHiddenByDefault: true),
                // Operator-facing error text: exception class + message, no credentials.
                TextColumn::make('backup_error')->label('Backup error')->limit(40)->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('backup_verified_at')->label('Backup verified')->since()->placeholder('–')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('created_at')->label('Uploaded')->dateTime()->sortable()->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('deleted_at')->label('Trashed')->since()->placeholder('–')->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('protection')
                    ->options(collect(self::PROTECTION_STATES)->mapWithKeys(fn ($s) => [$s => StatusColors::label($s)])->all())
                    ->query(fn (Builder $query, array $data) => filled($data['value'] ?? null)
                        ? $query->whereRaw(MemoryPhoto::protectionStatusSql().' = ?', [$data['value']])
                        : $query),
            ])
            ->recordActions([
                self::operatorAction('retryBackup', 'Retry backup', 'retryBackup',
                    fn (MemoryPhoto $record) => $record->status === 'verified' && ! $record->isPurged() && $record->backup_status !== 'verified'),
                self::operatorAction('verifyIntegrity', 'Run integrity check', 'verifyIntegrity',
                    fn (MemoryPhoto $record) => $record->status === 'verified' && ! $record->isPurged()),
                self::operatorAction('requestRepair', 'Request repair', 'requestRepair',
                    fn (MemoryPhoto $record) => $record->status === 'verified' && ! $record->isPurged()
                        && in_array($record->protectionStatus(), ['degraded', 'restoring'], true)),
            ])
            ->toolbarActions([])
            ->emptyStateIcon('heroicon-o-server-stack')
            ->emptyStateHeading('No photos match')
            ->emptyStateDescription('Only ciphertext metadata is listed here. Photos themselves are never viewable in admin.');
    }

    private static function operatorAction(string $name, string $label, string $method, \Closure $visible): Action
    {
        return Action::make($name)
            ->label($label)
            ->requiresConfirmation()
            ->visible($visible)
            ->action(function (MemoryPhoto $record) use ($label, $method): void {
                try {
                    app(StorageOperatorActions::class)->{$method}($record, auth()->user());
                    Notification::make()->title("{$label}: queued")->success()->send();
                } catch (RuntimeException $exception) {
                    Notification::make()->title($exception->getMessage())->danger()->send();
                }
            });
    }
}
