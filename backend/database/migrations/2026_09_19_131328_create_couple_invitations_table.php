<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('couple_invitations', function (Blueprint $table) {
            $table->id();

            $table->foreignId('couple_id')
                ->constrained('couples')
                ->cascadeOnDelete();

            $table->foreignId('invited_by')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->string('token', 64)->unique();

            $table->string('status', 20)
                ->default('pending');

            $table->timestamp('expires_at');

            $table->timestamp('accepted_at')->nullable();

            $table->timestamps();

            $table->index(['couple_id', 'status']);
            $table->index(['invited_by', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('couple_invitations');
    }
};
