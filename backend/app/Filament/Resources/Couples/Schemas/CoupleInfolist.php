<?php

namespace App\Filament\Resources\Couples\Schemas;

use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Schema;

class CoupleInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextEntry::make('id')
                    ->label('Couple ID'),

                TextEntry::make('invite_code')
                    ->label('Invite Code')
                    ->placeholder('-'),

                TextEntry::make('members_count')
                    ->label('Members')
                    ->state(fn($record) => $record->members()->count()),

                TextEntry::make('members')
                    ->label('Member Details')
                    ->state(function ($record) {
                        return $record->members()
                            ->with('user')
                            ->get()
                            ->map(function ($member) {
                                return "{$member->user->name} ({$member->user->email})";
                            })
                            ->implode("\n");
                    })
                    ->placeholder('-'),

                TextEntry::make('created_at')
                    ->dateTime()
                    ->placeholder('-'),

                TextEntry::make('updated_at')
                    ->dateTime()
                    ->placeholder('-'),
            ]);
    }
}
