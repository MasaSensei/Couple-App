<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('memory_comments', function (Blueprint $table) {
            $table->id();

            $table->foreignId('memory_id')
                ->constrained('memories')
                ->cascadeOnDelete();

            $table->foreignId('user_id')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->text('body');

            $table->timestamps();
            $table->softDeletes();

            $table->index([
                'memory_id',
                'created_at',
            ]);

            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('memory_comments');
    }
};
