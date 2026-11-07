<?php

namespace App\Filament\Resources\SubscriptionPlans\Pages;

use App\Filament\Resources\SubscriptionPlans\SubscriptionPlanResource;
use App\Models\AdminAuditLog;
use Filament\Resources\Pages\EditRecord;

class EditSubscriptionPlan extends EditRecord
{
    protected static string $resource = SubscriptionPlanResource::class;

    protected function mutateFormDataBeforeSave(array $data): array
    {
        unset($data['key'], $data['is_free']);

        // The Free plan is everyone's fallback and must stay offered.
        if ($this->record->is_free) {
            $data['status'] = 'active';
        }

        return $data;
    }

    protected function afterSave(): void
    {
        $changes = array_diff_key($this->record->getChanges(), ['updated_at' => true]);

        if ($changes !== []) {
            AdminAuditLog::record(auth()->user(), 'plan_updated', $this->record, $changes);
        }
    }
}
