<?php

namespace Database\Factories;

use App\Models\Couple;
use App\Models\Date;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Date>
 */
class DateFactory extends Factory
{
    protected $model = Date::class;

    public function definition(): array
    {
        return [
            'couple_id' => Couple::factory(),
            'created_by' => User::factory(),
            'title' => fake()->sentence(3),
            'description' => fake()->optional()->paragraph(),
            'location' => fake()->optional()->address(),
            'scheduled_at' => now()->addDays(7),
            'status' => 'planned',
            'completed_at' => null,
        ];
    }
}
