<?php

namespace App\Filament\Resources\Couples\Tables;

use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class CouplesTable
{
    /**
     * The invite code lets anyone join a couple, so admin screens show only
     * its last two characters.
     */
    public static function maskInviteCode(?string $code): string
    {
        return $code === null ? '–' : str_repeat('•', max(strlen($code) - 2, 0)).substr($code, -2);
    }

    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->modifyQueryUsing(fn (Builder $query) => $query
                ->withCount(['members', 'memories'])
                ->with('members.user:id,name'))
            ->columns([
                TextColumn::make('id')
                    ->label('Couple')
                    ->prefix('#')
                    ->weight('semibold')
                    ->sortable()
                    ->searchable(),

                TextColumn::make('member_names')
                    ->label('Members')
                    ->state(fn ($record) => $record->members->map(fn ($m) => $m->user?->name ?? 'Deleted user')->implode(' & '))
                    ->placeholder('–')
                    ->wrap(),

                TextColumn::make('members_count')
                    ->label('Status')
                    ->badge()
                    ->formatStateUsing(fn (int $state) => $state >= 2 ? 'Complete' : 'Waiting for partner')
                    ->color(fn (int $state) => $state >= 2 ? 'success' : 'warning'),

                TextColumn::make('memories_count')
                    ->label('Memories')
                    ->numeric()
                    ->sortable(),

                TextColumn::make('invite_code')
                    ->label('Invite code')
                    ->formatStateUsing(fn (?string $state) => self::maskInviteCode($state))
                    ->fontFamily('mono')
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('created_at')
                    ->label('Created')
                    ->since()
                    ->dateTimeTooltip()
                    ->sortable(),
            ])
            ->filters([
                TernaryFilter::make('complete')
                    ->label('Both partners joined')
                    ->queries(
                        true: fn (Builder $q) => $q->has('members', '>=', 2),
                        false: fn (Builder $q) => $q->has('members', '<', 2),
                    ),
            ])
            ->recordActions([
                ViewAction::make(),
            ])
            ->toolbarActions([])
            ->emptyStateIcon('heroicon-o-user-group')
            ->emptyStateHeading('No couples yet')
            ->emptyStateDescription('Couples appear here when someone creates a space in the app.');
    }
}
