<?php

namespace App\Services\Storage;

use RuntimeException;

/**
 * The store answered and the object is not there. Distinct from a store that
 * could not be reached, which must never be recorded as data loss.
 */
class PhotoObjectMissingException extends RuntimeException {}
