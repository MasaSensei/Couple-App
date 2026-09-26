<?php

namespace Database\Factories;

use App\Models\Couple;
use App\Models\Memory;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Memory>
 */
class MemoryFactory extends Factory
{
    protected $model = Memory::class;

    public function definition(): array
    {
        return [
            'couple_id' => Couple::factory(),
            'created_by' => User::factory(),
            'date_id' => null,
            'title' => fake()->sentence(3),
            'description' => fake()->optional()->paragraph(),
            'memory_date' => fake()->date(),
            'location_name' => fake()->optional()->city(),
            'location_address' => fake()->optional()->address(),
            'latitude' => fake()->optional()->latitude(),
            'longitude' => fake()->optional()->longitude(),
        ];
    }
}
