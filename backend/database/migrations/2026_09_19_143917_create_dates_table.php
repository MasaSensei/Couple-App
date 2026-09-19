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
        Schema::create('dates', function (Blueprint $table) {
            $table->id();

            $table->foreignId('couple_id')
                ->constrained('couples')
                ->cascadeOnDelete();

            $table->foreignId('created_by')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->string('title', 150);

            $table->text('description')
                ->nullable();

            $table->string('location', 255)
                ->nullable();

            $table->timestamp('scheduled_at');

            $table->string('status', 20)
                ->default('planned');

            $table->timestamp('completed_at')
                ->nullable();

            $table->timestamps();

            $table->index([
                'couple_id',
                'scheduled_at',
            ]);

            $table->index([
                'couple_id',
                'status',
            ]);

            $table->index('created_by');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dates');
    }
};
