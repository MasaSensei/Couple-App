<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('memory_photos', function (Blueprint $table) {
            /*
             * null    = nothing to repair
             * pending = a bad copy was found; repair queued / running
             * failed  = no verified copy to restore from; needs an operator
             */
            $table->string('repair_status', 20)->nullable()->after('integrity_checked_at');
            $table->index(['repair_status', 'updated_at']);
        });

        // Append-only trail of storage operations (repair now; purge and admin actions later).
        Schema::create('photo_storage_audits', function (Blueprint $table) {
            $table->id();
            // Survives the photo row being purged.
            $table->foreignId('memory_photo_id')->nullable()->constrained('memory_photos')->nullOnDelete();
            $table->string('action', 40);
            $table->string('result', 20);
            $table->string('actor', 64);
            $table->string('detail', 255)->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['memory_photo_id', 'created_at']);
            $table->index(['action', 'result', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photo_storage_audits');

        Schema::table('memory_photos', function (Blueprint $table) {
            $table->dropIndex(['repair_status', 'updated_at']);
            $table->dropColumn('repair_status');
        });
    }
};
