<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('memories', function (Blueprint $table) {
            $table->id();

            $table->foreignId('couple_id')
                ->constrained('couples')
                ->cascadeOnDelete();

            $table->foreignId('created_by')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->foreignId('date_id')
                ->nullable()
                ->constrained('dates')
                ->nullOnDelete();

            $table->string('title', 150);

            $table->text('description')
                ->nullable();

            $table->date('memory_date');

            $table->string('location_name', 255)
                ->nullable();

            $table->string('location_address', 500)
                ->nullable();

            $table->decimal('latitude', 10, 7)
                ->nullable();

            $table->decimal('longitude', 10, 7)
                ->nullable();

            $table->timestamps();
            $table->softDeletes();

            $table->index([
                'couple_id',
                'memory_date',
                'created_at',
            ]);

            $table->index('date_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('memories');
    }
};
