<?php

namespace App\Filament\Resources\CoupleSubscriptions\Pages;

use App\Filament\BillingAccess;
use App\Filament\Resources\CoupleSubscriptions\CoupleSubscriptionResource;
use App\Models\Couple;
use App\Models\SubscriptionPlan;
use App\Services\Billing\AdminSubscriptionActions;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Pages\ListRecords;

class ListCoupleSubscriptions extends ListRecords
{
    protected static string $resource = CoupleSubscriptionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            BillingAccess::auditedAction('grant', 'Grant plan', function (array $data, $record, $admin): void {
                app(AdminSubscriptionActions::class)->grant(
                    Couple::findOrFail((int) $data['couple_id']),
                    SubscriptionPlan::findOrFail((int) $data['plan_id']),
                    (int) $data['days'],
                    $admin,
                    $data['reason'],
                );
            }, [
                TextInput::make('couple_id')->label('Couple ID')->numeric()->required(),
                Select::make('plan_id')->label('Plan')->required()
                    ->options(fn () => SubscriptionPlan::where('is_free', false)->whereHas('publishedVersion')->pluck('name', 'id')),
                TextInput::make('days')->numeric()->minValue(1)->maxValue(366)->required(),
            ]),
        ];
    }
}
