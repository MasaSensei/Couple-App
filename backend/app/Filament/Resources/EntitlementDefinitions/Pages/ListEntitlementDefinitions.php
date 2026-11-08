<?php

namespace App\Filament\Resources\EntitlementDefinitions\Pages;

use App\Filament\Resources\EntitlementDefinitions\EntitlementDefinitionResource;
use Filament\Resources\Pages\ListRecords;

class ListEntitlementDefinitions extends ListRecords
{
    protected static string $resource = EntitlementDefinitionResource::class;
}
