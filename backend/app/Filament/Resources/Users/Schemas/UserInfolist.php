<?php

namespace App\Filament\Resources\Users\Schemas;

use Filament\Infolists\Components\IconEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class UserInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->columns(2)
            ->components([
                Section::make('Profile')
                    ->description('Account identity. Passwords and keys are never shown.')
                    ->icon('heroicon-o-user')
                    ->columns(2)
                    ->columnSpan(1)
                    ->schema([
                        TextEntry::make('name'),
                        TextEntry::make('email')->label('Email address')->copyable(),
                        TextEntry::make('email_verified_at')
                            ->label('Email verified')
                            ->dateTime()
                            ->placeholder('Not verified'),
                        IconEntry::make('is_admin')->label('Admin')->boolean(),
                    ]),

                Section::make('Activity')
                    ->icon('heroicon-o-clock')
                    ->columns(2)
                    ->columnSpan(1)
                    ->schema([
                        TextEntry::make('created_at')->label('Joined')->dateTime()->placeholder('–'),
                        TextEntry::make('updated_at')->label('Last updated')->since()->placeholder('–'),
                        TextEntry::make('couple')
                            ->label('Couple')
                            ->state(fn ($record) => $record->coupleMemberships()->value('couple_id'))
                            ->formatStateUsing(fn ($state) => "Couple #{$state}")
                            ->placeholder('Not in a couple'),
                    ]),
            ]);
    }
}
