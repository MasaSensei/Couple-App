<?php

namespace App\Services\Billing\Providers;

use RuntimeException;

/** The provider says this purchase is not valid for this app or couple. */
class PurchaseVerificationFailed extends RuntimeException {}
