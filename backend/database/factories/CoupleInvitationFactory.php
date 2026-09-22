<?php

namespace Database\Factories;

use App\Models\Couple;
use App\Models\CoupleInvitation;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<CoupleInvitation>
 */
class CoupleInvitationFactory extends Factory
{
    protected $model = CoupleInvitation::class;

    public function definition(): array
    {
        return [
            'couple_id' => Couple::factory(),
            'invited_by' => User::factory(),
            'token' => Str::random(64),
            'status' => 'pending',
            'expires_at' => now()->addDays(7),
            'accepted_at' => null,
        ];
    }
}
