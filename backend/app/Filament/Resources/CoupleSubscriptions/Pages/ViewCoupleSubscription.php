<?php

namespace App\Filament\Resources\CoupleSubscriptions\Pages;

use App\Filament\Resources\CoupleSubscriptions\CoupleSubscriptionResource;
use Filament\Resources\Pages\ViewRecord;

class ViewCoupleSubscription extends ViewRecord
{
    protected static string $resource = CoupleSubscriptionResource::class;

    protected function getHeaderActions(): array
    {
        return CoupleSubscriptionResource::manageActions();
    }
}
