<?php

namespace App\Filament\Resources\EntitlementDefinitions\Pages;

use App\Filament\Resources\EntitlementDefinitions\EntitlementDefinitionResource;
use App\Models\AdminAuditLog;
use Filament\Resources\Pages\EditRecord;

class EditEntitlementDefinition extends EditRecord
{
    protected static string $resource = EntitlementDefinitionResource::class;

    protected function afterSave(): void
    {
        $changes = array_diff_key($this->record->getChanges(), ['updated_at' => true]);

        if ($changes !== []) {
            AdminAuditLog::record(auth()->user(), 'entitlement_definition_updated', $this->record, $changes);
        }
    }
}
