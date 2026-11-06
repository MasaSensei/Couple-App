<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('memory_photos', function (Blueprint $table) {
            /*
             * Independent backup copy. Kept separate from `status` (the upload
             * workflow) so the two never overlap:
             *   null     = nothing to back up yet (upload not verified)
             *   pending  = queued / retrying
             *   verified = backup copy matches `checksum`
             *   failed   = retries exhausted; needs an operator
             */
            $table->string('backup_status', 20)->nullable()->after('status');
            $table->timestamp('backup_verified_at')->nullable()->after('backup_status');
            $table->string('backup_error', 255)->nullable()->after('backup_verified_at');

            $table->index(['backup_status', 'updated_at']);
        });

        // Photos verified before Phase 6 have no backup yet.
        DB::table('memory_photos')
            ->where('status', 'verified')
            ->update(['backup_status' => 'pending']);
    }

    public function down(): void
    {
        Schema::table('memory_photos', function (Blueprint $table) {
            $table->dropIndex(['backup_status', 'updated_at']);
            $table->dropColumn(['backup_status', 'backup_verified_at', 'backup_error']);
        });
    }
};
