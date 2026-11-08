<?php

namespace App\Providers;

use App\Models\Memory;
use App\Models\MemoryComment;
use App\Models\MemoryPhoto;
use App\Policies\MemoryCommentPolicy;
use App\Policies\MemoryPhotoPolicy;
use App\Policies\MemoryPolicy;
use App\Services\Storage\FlysystemPhotoStorage;
use App\Services\Storage\PhotoStorage;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(
            PhotoStorage::class,
            fn () => new FlysystemPhotoStorage('photos_primary'),
        );

        // Independent copy; only backup/repair jobs use it.
        $this->app->bind(
            'photos.backup',
            fn () => new FlysystemPhotoStorage('photos_backup'),
        );
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiting();

        // API users. Admin accounts have a stricter rule in the admin user form.
        Password::defaults(fn () => Password::min(8)->max(128));

        Gate::policy(
            Memory::class,
            MemoryPolicy::class,
        );

        Gate::policy(
            MemoryPhoto::class,
            MemoryPhotoPolicy::class,
        );

        Gate::policy(
            MemoryComment::class,
            MemoryCommentPolicy::class,
        );
    }

    /** Named limiters used in routes/api.php. Limits live in config/security.php. */
    private function configureRateLimiting(): void
    {
        // Read per request so limits follow the current config.
        $limits = fn (string $key): int => (int) config("security.rate_limits.{$key}");

        // Login/register: slows credential stuffing per account and per source IP.
        RateLimiter::for('auth', fn (Request $request) => [
            Limit::perMinute($limits('auth_per_identity'))
                ->by('auth:'.Str::lower((string) $request->input('email')).'|'.$request->ip()),
            Limit::perMinute($limits('auth_per_ip'))->by('auth-ip:'.$request->ip()),
        ]);

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute($limits('api_per_user'))
            ->by($request->user()?->getAuthIdentifier() ?? 'ip:'.$request->ip()));

        RateLimiter::for('uploads', fn (Request $request) => Limit::perMinute($limits('uploads_per_user'))
            ->by('upload:'.($request->user()?->getAuthIdentifier() ?? $request->ip())));

        RateLimiter::for('public', fn (Request $request) => Limit::perMinute($limits('public_per_ip'))
            ->by('public:'.$request->ip()));
    }
}
