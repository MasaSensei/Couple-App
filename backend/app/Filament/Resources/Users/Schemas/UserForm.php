<?php

namespace App\Filament\Resources\Users\Schemas;

use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;
use Illuminate\Validation\Rules\Password;

class UserForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->required(),
                TextInput::make('email')
                    ->label('Email address')
                    ->email()
                    ->required(),
                DateTimePicker::make('email_verified_at'),
                // Only set when typed; never pre-filled with the stored hash.
                TextInput::make('password')
                    ->password()
                    ->revealable(false)
                    ->rule(Password::min(config('security.admin.password_min_length'))->letters()->mixedCase()->numbers())
                    ->required(fn (string $operation): bool => $operation === 'create')
                    ->dehydrated(fn (?string $state): bool => filled($state))
                    ->formatStateUsing(fn (): ?string => null),
                // Admin rights are granted with `php artisan admin:role`, so a
                // compromised admin account cannot create more admins.
                Toggle::make('is_admin')
                    ->disabled()
                    ->dehydrated(false)
                    ->helperText('Managed with: php artisan admin:role grant|revoke <email>'),
            ]);
    }
}
