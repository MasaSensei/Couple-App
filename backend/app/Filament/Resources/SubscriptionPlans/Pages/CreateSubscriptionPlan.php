<?php

namespace App\Filament\Resources\SubscriptionPlans\Pages;

use App\Filament\Resources\SubscriptionPlans\SubscriptionPlanResource;
use App\Models\AdminAuditLog;
use Filament\Resources\Pages\CreateRecord;

class CreateSubscriptionPlan extends CreateRecord
{
    protected static string $resource = SubscriptionPlanResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        // New plans are paid plans; the single Free plan is created by the system.
        return [...$data, 'is_free' => false];
    }

    protected function afterCreate(): void
    {
        AdminAuditLog::record(auth()->user(), 'plan_created', $this->record, $this->record->only(['key', 'name', 'status']));
    }
}
