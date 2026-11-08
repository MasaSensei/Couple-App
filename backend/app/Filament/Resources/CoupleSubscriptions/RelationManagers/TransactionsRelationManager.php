<?php

namespace App\Filament\Resources\CoupleSubscriptions\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

/** Transaction metadata only; store transaction ids are hidden by default. */
class TransactionsRelationManager extends RelationManager
{
    protected static string $relationship = 'transactions';

    public function isReadOnly(): bool
    {
        return true;
    }

    public function table(Table $table): Table
    {
        return $table
            ->defaultSort('occurred_at', 'desc')
            ->columns([
                TextColumn::make('occurred_at')->dateTime(),
                TextColumn::make('type')->badge(),
                TextColumn::make('amount')->numeric(),
                TextColumn::make('currency'),
                TextColumn::make('provider'),
                TextColumn::make('provider_transaction_id')->label('Store transaction')->limit(16)->toggleable(isToggledHiddenByDefault: true),
            ]);
    }
}
