<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One row per db:backup run. Never holds keys or dump content.
        Schema::create('database_backups', function (Blueprint $table) {
            $table->id();
            $table->string('object_key', 255)->nullable();
            $table->string('status', 20); // running | succeeded | failed
            $table->unsignedBigInteger('size_bytes')->nullable();
            $table->char('sha256', 64)->nullable();
            // Row counts of key tables just before the dump, for the restore check.
            $table->json('table_counts')->nullable();
            $table->string('error', 255)->nullable();
            $table->timestamp('started_at');
            $table->timestamp('finished_at')->nullable();
            $table->timestamp('restore_checked_at')->nullable();
            $table->string('restore_result', 20)->nullable(); // passed | failed
            $table->text('restore_detail')->nullable();
            $table->timestamps();

            $table->index(['status', 'finished_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('database_backups');
    }
};
