<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use App\Models\Memory;
use App\Policies\MemoryPolicy;
use Illuminate\Support\Facades\Gate;
use App\Services\Storage\FlysystemPhotoStorage;
use App\Services\Storage\PhotoStorage;
use App\Models\MemoryPhoto;
use App\Policies\MemoryPhotoPolicy;
use App\Models\MemoryComment;
use App\Policies\MemoryCommentPolicy;

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
}
