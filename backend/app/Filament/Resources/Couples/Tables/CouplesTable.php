<?php

namespace App\Filament\Resources\Couples\Tables;

use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class CouplesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')
                    ->label('Couple ID')
                    ->sortable(),

                TextColumn::make('invite_code')
                    ->label('Invite Code')
                    ->searchable(),

                TextColumn::make('members_count')
                    ->label('Members')
                    ->counts('members'),

                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable(),

                TextColumn::make('updated_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([])
            ->recordActions([
                ViewAction::make(),
            ])
            ->toolbarActions([]);
    }
}
