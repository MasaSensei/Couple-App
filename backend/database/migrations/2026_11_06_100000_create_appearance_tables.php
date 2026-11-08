<?php

use App\Services\Appearance\AppearanceCatalog;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        /*
         * Catalog metadata only. How a theme or template looks lives in the
         * Flutter app; these rows decide what is offered and let admins
         * hide/retire items or mark them premium (Phase 8) without a release.
         */
        Schema::create('themes', function (Blueprint $table) {
            $table->id();
            $table->string('key', 64)->unique();
            $table->string('name', 100);
            $table->unsignedInteger('version')->default(1);
            $table->string('status', 20)->default('active'); // active | hidden | retired
            $table->boolean('is_default')->default(false);
            $table->boolean('is_premium')->default(false);
            $table->unsignedInteger('sort_order')->default(0);
            // Allowed customization preset keys: {accents: [], backgrounds: [], fonts: []}.
            $table->json('options');
            $table->timestamps();
        });

        Schema::create('photo_booth_templates', function (Blueprint $table) {
            $table->id();
            $table->string('key', 64)->unique();
            $table->string('name', 100);
            $table->unsignedInteger('version')->default(1);
            $table->unsignedSmallInteger('photo_slots');
            $table->string('status', 20)->default('active');
            $table->boolean('is_premium')->default(false);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        /*
         * The couple's shared appearance. One row per couple; `version` is an
         * optimistic lock so two partners changing it at once never silently
         * overwrite each other. Personal preferences (dark mode, reduce
         * motion) are device-local and deliberately not stored here.
         */
        Schema::create('couple_theme_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->unique()->constrained('couples')->cascadeOnDelete();
            $table->string('theme_key', 64);
            $table->unsignedInteger('theme_version');
            $table->json('customization');
            $table->unsignedInteger('version');
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        app(AppearanceCatalog::class)->sync();
    }

    public function down(): void
    {
        Schema::dropIfExists('couple_theme_settings');
        Schema::dropIfExists('photo_booth_templates');
        Schema::dropIfExists('themes');
    }
};
