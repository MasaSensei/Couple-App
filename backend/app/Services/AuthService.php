<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;

class AuthService
{
    public const TOKEN_NAME = 'flutter-app';

    public function register(array $data): array
    {
        $user = User::create(['name' => $data['name'], 'email' => $data['email'], 'password' => $data['password']]);

        return ['user' => $user, ...$this->issueToken($user)];
    }

    public function login(array $credentials): array
    {
        $user = User::where('email', $credentials['email'])->first();

        // Hash a dummy value for unknown emails so response time does not reveal which emails exist.
        static $dummyHash = null;
        $dummyHash ??= Hash::make('timing-equaliser');

        $valid = $user !== null
            ? Hash::check($credentials['password'], $user->password)
            : Hash::check($credentials['password'], $dummyHash) && false;

        if (! $valid) {
            // Pseudonymous: lets operators spot stuffing against one account without logging emails.
            Log::warning('auth.login_failed', ['email_hash' => substr(hash('sha256', Str::lower($credentials['email'])), 0, 16)]);

            throw ValidationException::withMessages(['email' => ['The provided credentials are incorrect.']]);
        }

        return ['user' => $user, ...$this->issueToken($user)];
    }

    /**
     * Replace the caller's token with a fresh one (same device binding) and
     * revoke the old one. Called by the app before the token expires.
     */
    public function refresh(User $user, PersonalAccessToken $current): array
    {
        return DB::transaction(function () use ($user, $current): array {
            $issued = $this->issueToken($user, $current->user_device_id);
            $current->delete();

            return $issued;
        });
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }

    /** Sign out every session of this user (e.g. after a suspected compromise). */
    public function logoutAll(User $user): int
    {
        return $user->tokens()->delete();
    }

    /** @return array{token: string, token_expires_at: string} */
    private function issueToken(User $user, ?int $deviceId = null): array
    {
        $expiresAt = now()->addDays(config('security.token_ttl_days'));
        $token = $user->createToken(self::TOKEN_NAME, ['*'], $expiresAt);

        if ($deviceId !== null) {
            $token->accessToken->forceFill(['user_device_id' => $deviceId])->save();
        }

        return ['token' => $token->plainTextToken, 'token_expires_at' => $expiresAt->toIso8601String()];
    }
}
