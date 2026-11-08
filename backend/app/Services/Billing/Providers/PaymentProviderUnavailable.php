<?php

namespace App\Services\Billing\Providers;

use RuntimeException;

/** Provider unreachable or not configured. Retry later; never treated as "not paid". */
class PaymentProviderUnavailable extends RuntimeException {}
