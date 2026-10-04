<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('user_devices', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->string('device_identifier', 128);

            $table->string('device_name', 255)->nullable();

            $table->string('platform', 32);

            $table->text('public_key');

            $table->timestamp('last_seen_at')->nullable();

            $table->timestamp('revoked_at')->nullable();

            $table->timestamps();

            $table->unique(['user_id', 'device_identifier']);
            $table->index(['user_id', 'revoked_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('user_devices');
    }
};
