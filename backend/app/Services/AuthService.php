<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public function register(array $data): array
    {
        $user = User::create(['name' => $data['name'], 'email' => $data['email'], 'password' => $data['password'],]);
        return ['user' => $user, 'token' => $user->createToken('flutter-app')->plainTextToken,];
    }
    public function login(array $credentials): array
    {
        $user = User::where('email', $credentials['email'])->first();
        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => ['The provided credentials are incorrect.'],]);
        }
        return ['user' => $user, 'token' => $user->createToken('flutter-app')->plainTextToken,];
    }
    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }
}
