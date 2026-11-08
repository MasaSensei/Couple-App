<?php

namespace App\Filament\Resources\Couples\Schemas;

use App\Filament\Resources\Couples\Tables\CouplesTable;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

/**
 * Couple overview for support. Counts and metadata only: no memory titles,
 * comments or photos (those are private to the couple).
 */
class CoupleInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->columns(3)
            ->components([
                Section::make('Overview')
                    ->icon('heroicon-o-user-group')
                    ->columns(2)
                    ->columnSpan(2)
                    ->schema([
                        TextEntry::make('id')->label('Couple')->prefix('#'),
                        TextEntry::make('status')
                            ->badge()
                            ->state(fn ($record) => $record->members()->count() >= 2 ? 'Complete' : 'Waiting for partner')
                            ->color(fn (string $state) => $state === 'Complete' ? 'success' : 'warning'),
                        TextEntry::make('members_list')
                            ->label('Members')
                            ->state(fn ($record) => $record->members()->with('user:id,name,email')->get()
                                ->map(fn ($m) => $m->user ? "{$m->user->name} ({$m->user->email})" : 'Deleted user')
                                ->all())
                            ->listWithLineBreaks()
                            ->placeholder('–')
                            ->columnSpanFull(),
                        TextEntry::make('created_at')->label('Space created')->dateTime(),
                        TextEntry::make('updated_at')->label('Last updated')->since(),
                    ]),

                Section::make('Content')
                    ->description('Counts only. Content and photos stay private to the couple.')
                    ->icon('heroicon-o-lock-closed')
                    ->columnSpan(1)
                    ->schema([
                        TextEntry::make('memories_count')
                            ->label('Memories')
                            ->state(fn ($record) => $record->memories()->count()),
                        TextEntry::make('invite_code')
                            ->label('Invite code')
                            ->formatStateUsing(fn (?string $state) => CouplesTable::maskInviteCode($state))
                            ->fontFamily('mono')
                            ->helperText('Masked: the full code lets anyone join this couple.')
                            ->placeholder('–'),
                    ]),
            ]);
    }
}
