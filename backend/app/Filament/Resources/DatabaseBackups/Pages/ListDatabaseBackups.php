<?php

namespace App\Filament\Resources\DatabaseBackups\Pages;

use App\Filament\Resources\DatabaseBackups\DatabaseBackupResource;
use Filament\Resources\Pages\ListRecords;

class ListDatabaseBackups extends ListRecords
{
    protected static string $resource = DatabaseBackupResource::class;
}
