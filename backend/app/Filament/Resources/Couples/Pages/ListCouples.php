<?php

namespace App\Filament\Resources\Couples\Pages;

use App\Filament\Resources\Couples\CoupleResource;
use Filament\Resources\Pages\ListRecords;

class ListCouples extends ListRecords
{
    protected static string $resource = CoupleResource::class;
}
