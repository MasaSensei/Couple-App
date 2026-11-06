<?php

namespace App\Services\Appearance;

use RuntimeException;

/** The couple's theme changed since the client last read it. */
class ThemeVersionConflict extends RuntimeException
{
    public function __construct(public readonly array $current)
    {
        parent::__construct('Your partner changed the theme a moment ago.');
    }
}
