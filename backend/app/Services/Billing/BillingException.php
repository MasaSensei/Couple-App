<?php

namespace App\Services\Billing;

use RuntimeException;

/** A refused billing action with a stable machine-readable code for the app. */
class BillingException extends RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status = 422,
        public readonly array $data = [],
    ) {
        parent::__construct($message);
    }
}
