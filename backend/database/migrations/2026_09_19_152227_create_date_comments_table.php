<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('date_comments', function (Blueprint $table) {
            $table->id();

            $table->foreignId('date_id')
                ->constrained('dates')
                ->cascadeOnDelete();

            $table->foreignId('user_id')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->text('content');

            $table->timestamps();

            $table->index([
                'date_id',
                'created_at',
            ]);

            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('date_comments');
    }
};
