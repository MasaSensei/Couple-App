<?php

namespace App\Filament\Widgets;

use App\Filament\Support\StatusColors;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget;

/** Latest operator actions on photo storage (from the storage audit log). */
class RecentOperatorActivity extends TableWidget
{
    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    protected static ?string $heading = 'Recent administrative activity';

    public static function canView(): bool
    {
        return auth()->user()?->is_admin === true;
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(
                PhotoStorageAudit::query()
                    ->where('actor', 'like', 'user:%')
                    ->latest('id')
                    ->limit(8)
            )
            ->paginated(false)
            ->columns([
                TextColumn::make('created_at')->label('When')->since()->tooltip(fn ($record) => $record->created_at?->toDateTimeString()),
                TextColumn::make('action')
                    ->formatStateUsing(fn (string $state) => StatusColors::label(preg_replace('/^admin_/', '', $state)))
                    ->weight('medium'),
                TextColumn::make('memory_photo_id')->label('Photo')->prefix('#')->placeholder('–'),
                TextColumn::make('result')->badge()
                    ->formatStateUsing(fn (string $state) => StatusColors::label($state))
                    ->color(fn (string $state) => StatusColors::for($state)),
                TextColumn::make('actor')->label('By')
                    ->formatStateUsing(fn (string $state) => self::actorLabel($state)),
            ])
            ->emptyStateIcon('heroicon-o-clipboard-document-check')
            ->emptyStateHeading('No operator actions yet')
            ->emptyStateDescription('Retries, integrity checks and repairs started by an admin appear here.');
    }

    private static function actorLabel(string $actor): string
    {
        if (! str_starts_with($actor, 'user:')) {
            return $actor;
        }

        $email = User::query()->whereKey((int) substr($actor, 5))->value('email');

        return $email ?? 'Deleted admin';
    }
}
