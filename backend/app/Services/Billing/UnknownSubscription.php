<?php

namespace App\Services\Billing;

use RuntimeException;

/** A provider subscription that is not linked to any couple (yet). */
class UnknownSubscription extends RuntimeException {}
