<?php

namespace App\Services\Billing\Providers;

use RuntimeException;

/** A webhook whose signature did not verify. Nothing from it is stored or applied. */
class InvalidWebhookSignature extends RuntimeException {}
