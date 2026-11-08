<?php

namespace App\Filament\Resources\MemoryPhotos\Pages;

use App\Filament\Resources\MemoryPhotos\MemoryPhotoResource;
use App\Filament\Widgets\StorageHealthOverview;
use Filament\Resources\Pages\ListRecords;

class ListMemoryPhotos extends ListRecords
{
    protected static string $resource = MemoryPhotoResource::class;

    protected function getHeaderWidgets(): array
    {
        return [StorageHealthOverview::class];
    }
}
