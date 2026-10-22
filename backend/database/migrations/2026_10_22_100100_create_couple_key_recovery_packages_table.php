<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Couple Key encrypted with the user's Recovery Key.
        // The Recovery Key itself is never sent to the server.
        Schema::create('couple_key_recovery_packages', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')
                ->unique()
                ->constrained()
                ->cascadeOnDelete();

            $table->foreignId('couple_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->string('key_id', 128);

            $table->unsignedSmallInteger('format_version');

            $table->text('nonce');

            $table->text('ciphertext');

            $table->text('mac');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('couple_key_recovery_packages');
    }
};
