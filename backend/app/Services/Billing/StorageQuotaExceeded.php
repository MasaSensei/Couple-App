<?php

namespace App\Services\Billing;

use RuntimeException;

class StorageQuotaExceeded extends RuntimeException
{
    public function __construct(public readonly array $usage)
    {
        parent::__construct(
            'Your shared photo storage is full. Existing photos stay safe and viewable; '
            .'free up space by deleting photos or choose a plan with more storage.',
        );
    }
}
