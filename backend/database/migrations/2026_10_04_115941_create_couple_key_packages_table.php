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
        Schema::create('couple_key_packages', function (Blueprint $table) {
            $table->id();

            $table->foreignId('couple_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->foreignId('device_id')
                ->constrained('user_devices')
                ->cascadeOnDelete();

            $table->string('key_id', 128);

            $table->unsignedSmallInteger('encryption_version');

            $table->text('ephemeral_public_key');

            $table->text('nonce');

            $table->text('ciphertext');

            $table->text('mac');

            $table->timestamp('revoked_at')->nullable();

            $table->timestamps();

            $table->unique([
                'couple_id',
                'device_id',
                'key_id',
            ]);

            $table->index([
                'couple_id',
                'revoked_at',
            ]);

            $table->index([
                'device_id',
                'revoked_at',
            ]);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('couple_key_packages');
    }
};
