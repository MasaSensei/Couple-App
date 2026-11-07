<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Liveness of background processes (scheduler, queue worker). Stored in
// PostgreSQL, not Redis, so a Redis outage cannot hide itself.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ops_heartbeats', function (Blueprint $table) {
            $table->string('name', 32)->primary();
            $table->timestampTz('beat_at');
            $table->string('host', 128)->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ops_heartbeats');
    }
};
