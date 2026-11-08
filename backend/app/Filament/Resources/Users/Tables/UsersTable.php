<?php

namespace App\Filament\Resources\Users\Tables;

use Filament\Actions\ViewAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class UsersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->modifyQueryUsing(fn (Builder $query) => $query->withCount('coupleMemberships'))
            ->columns([
                TextColumn::make('name')
                    ->weight('semibold')
                    ->description(fn ($record) => $record->email)
                    ->searchable(['name', 'email'])
                    ->sortable(),

                TextColumn::make('is_admin')
                    ->label('Role')
                    ->badge()
                    ->state(fn ($record) => $record->is_admin ? 'Admin' : 'Member')
                    ->color(fn (string $state) => $state === 'Admin' ? 'primary' : 'gray'),

                IconColumn::make('couple_memberships_count')
                    ->label('In a couple')
                    ->boolean()
                    ->state(fn ($record) => $record->couple_memberships_count > 0),

                IconColumn::make('email_verified_at')
                    ->label('Verified')
                    ->boolean()
                    ->state(fn ($record) => $record->email_verified_at !== null)
                    ->toggleable(),

                TextColumn::make('created_at')
                    ->label('Joined')
                    ->since()
                    ->dateTimeTooltip()
                    ->sortable(),

                TextColumn::make('id')
                    ->label('ID')
                    ->prefix('#')
                    ->color('gray')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                TernaryFilter::make('is_admin')->label('Admins'),
                TernaryFilter::make('email_verified_at')
                    ->label('Email verified')
                    ->nullable(),
                TernaryFilter::make('in_couple')
                    ->label('In a couple')
                    ->queries(
                        true: fn (Builder $q) => $q->has('coupleMemberships'),
                        false: fn (Builder $q) => $q->doesntHave('coupleMemberships'),
                    ),
            ])
            ->recordActions([
                ViewAction::make(),
            ])
            ->toolbarActions([])
            ->emptyStateIcon('heroicon-o-users')
            ->emptyStateHeading('No users match')
            ->emptyStateDescription('Try a different search or clear the filters.');
    }
}
