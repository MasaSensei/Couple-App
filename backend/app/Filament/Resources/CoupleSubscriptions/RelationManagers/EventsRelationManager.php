<?php

namespace App\Filament\Resources\CoupleSubscriptions\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

/** Read-only audit trail. */
class EventsRelationManager extends RelationManager
{
    protected static string $relationship = 'events';

    protected static ?string $title = 'Audit trail';

    public function isReadOnly(): bool
    {
        return true;
    }

    public function table(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('created_at')->dateTime(),
                TextColumn::make('type')->badge(),
                TextColumn::make('from_status')->placeholder('–'),
                TextColumn::make('to_status')->placeholder('–'),
                TextColumn::make('actor'),
                TextColumn::make('reason')->limit(80)->placeholder('–'),
            ]);
    }
}
