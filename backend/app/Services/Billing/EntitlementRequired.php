<?php

namespace App\Services\Billing;

use RuntimeException;

/** The couple's plan does not include $entitlement. Rendered as 403 with a code. */
class EntitlementRequired extends RuntimeException
{
    public function __construct(public readonly string $entitlement, string $message)
    {
        parent::__construct($message);
    }
}
