<?php

namespace App\Filament\Resources\MemoryPhotos\Tables;

use App\Models\MemoryPhoto;
use App\Services\Storage\StorageOperatorActions;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use RuntimeException;

class MemoryPhotosTable
{
    private const PROTECTION_COLORS = [
        'protected' => 'success',
        'backup_pending' => 'info',
        'restoring' => 'warning',
        'pending_upload' => 'gray',
        'degraded' => 'danger',
        'failed' => 'danger',
        'deleted' => 'gray',
    ];

    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('id')->label('Photo ID')->sortable(),
                TextColumn::make('memory_id')->label('Memory ID'),
                TextColumn::make('memory.couple_id')->label('Couple ID'),
                TextColumn::make('protection')
                    ->label('Protection')
                    ->badge()
                    ->state(fn (MemoryPhoto $record) => $record->protectionStatus())
                    ->color(fn (string $state) => self::PROTECTION_COLORS[$state] ?? 'gray'),
                TextColumn::make('status')->label('Upload'),
                TextColumn::make('backup_status')->label('Backup')->placeholder('–'),
                TextColumn::make('primary_integrity')->label('Primary check')->placeholder('–'),
                TextColumn::make('backup_integrity')->label('Backup check')->placeholder('–'),
                TextColumn::make('repair_status')->label('Repair')->placeholder('–'),
                TextColumn::make('encrypted_size')->label('Encrypted size')->numeric()->suffix(' B'),
                TextColumn::make('encryption_version')->label('Enc. version'),
                TextColumn::make('key_id')->label('Key ID')->limit(12)->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('checksum')->label('Checksum (SHA-256 of ciphertext)')->limit(16)->toggleable(isToggledHiddenByDefault: true),
                // Operator-facing error text: exception class + message, no credentials.
                TextColumn::make('backup_error')->label('Backup error')->limit(40)->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('integrity_checked_at')->label('Last check')->since()->placeholder('never'),
                TextColumn::make('backup_verified_at')->label('Backup verified')->since()->placeholder('–')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('created_at')->dateTime()->sortable(),
                TextColumn::make('deleted_at')->label('Trashed')->since()->placeholder('–')->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('protection')
                    ->options(array_combine(array_keys(self::PROTECTION_COLORS), array_keys(self::PROTECTION_COLORS)))
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
            ->toolbarActions([]);
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
