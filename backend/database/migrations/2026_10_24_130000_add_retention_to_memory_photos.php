<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('memory_photos', function (Blueprint $table) {
            // Set when each copy is removed by the retention purge, never by a user action.
            $table->timestamp('primary_purged_at')->nullable()->after('repair_status');
            $table->timestamp('backup_purged_at')->nullable()->after('primary_purged_at');
            $table->index(['deleted_at', 'primary_purged_at']);
        });

        /*
         * Hard deletes must never remove photo rows: without `nonce`/`mac` the
         * ciphertext can never be decrypted. Photos leave only via the purge.
         */
        Schema::table('memory_photos', function (Blueprint $table) {
            $table->dropForeign(['memory_id']);
            $table->dropForeign(['uploaded_by']);
        });

        Schema::table('memory_photos', function (Blueprint $table) {
            $table->unsignedBigInteger('uploaded_by')->nullable()->change();
            $table->foreign('memory_id')->references('id')->on('memories')->restrictOnDelete();
            $table->foreign('uploaded_by')->references('id')->on('users')->nullOnDelete();
        });

        Schema::table('memories', function (Blueprint $table) {
            $table->dropForeign(['couple_id']);
            $table->dropForeign(['created_by']);
        });

        Schema::table('memories', function (Blueprint $table) {
            $table->unsignedBigInteger('created_by')->nullable()->change();
            $table->foreign('couple_id')->references('id')->on('couples')->restrictOnDelete();
            $table->foreign('created_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('memories', function (Blueprint $table) {
            $table->dropForeign(['couple_id']);
            $table->dropForeign(['created_by']);
            $table->foreign('couple_id')->references('id')->on('couples')->cascadeOnDelete();
            $table->foreign('created_by')->references('id')->on('users')->cascadeOnDelete();
        });

        Schema::table('memory_photos', function (Blueprint $table) {
            $table->dropForeign(['memory_id']);
            $table->dropForeign(['uploaded_by']);
            $table->foreign('memory_id')->references('id')->on('memories')->cascadeOnDelete();
            $table->foreign('uploaded_by')->references('id')->on('users')->cascadeOnDelete();

            $table->dropIndex(['deleted_at', 'primary_purged_at']);
            $table->dropColumn(['primary_purged_at', 'backup_purged_at']);
        });
    }
};
