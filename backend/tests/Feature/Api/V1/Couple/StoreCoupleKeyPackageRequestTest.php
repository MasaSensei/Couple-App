<?php

namespace Tests\Feature\Api\V1\Couple;

use Tests\TestCase;

class StoreCoupleKeyPackageRequestTest extends TestCase
{
    public function test_request_class_exists(): void
    {
        $this->assertTrue(
            class_exists(
                \App\Http\Requests\Api\V1\Couple\StoreCoupleKeyPackageRequest::class,
            ),
        );
    }
}
