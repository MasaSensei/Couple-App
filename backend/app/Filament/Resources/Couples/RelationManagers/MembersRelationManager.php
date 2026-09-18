<?php

namespace App\Filament\Resources\Couples\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class MembersRelationManager extends RelationManager
{
    protected static string $relationship = 'members';

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('user_id')
            ->columns([
                TextColumn::make('user.id')
                    ->label('User ID')
                    ->sortable(),

                TextColumn::make('user.name')
                    ->label('Name')
                    ->searchable(),

                TextColumn::make('user.email')
                    ->label('Email')
                    ->searchable(),

                TextColumn::make('created_at')
                    ->label('Joined At')
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([])
            ->headerActions([])
            ->recordActions([])
            ->toolbarActions([]);
    }
}
