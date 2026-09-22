<?php

namespace Database\Factories;

use App\Models\Couple;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Couple>
 */
class CoupleFactory extends Factory
{
    protected $model = Couple::class;

    public function definition(): array
    {
        return [
            'invite_code' => Str::upper(
                Str::random(8)
            ),
        ];
    }
}
