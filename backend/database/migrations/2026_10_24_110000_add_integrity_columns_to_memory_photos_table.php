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
             * Result of the last re-hash of each copy against `checksum`:
             *   null     = not checked yet
             *   ok       = bytes match
             *   mismatch = bytes differ (corrupt / overwritten)
             *   missing  = store answered, object absent
             * An unreachable store never changes these values.
             */
            $table->string('primary_integrity', 20)->nullable()->after('backup_error');
            $table->string('backup_integrity', 20)->nullable()->after('primary_integrity');
            $table->timestamp('integrity_checked_at')->nullable()->after('backup_integrity');

            $table->index(['status', 'integrity_checked_at']);
        });
    }

    public function down(): void
    {
        Schema::table('memory_photos', function (Blueprint $table) {
            $table->dropIndex(['status', 'integrity_checked_at']);
            $table->dropColumn(['primary_integrity', 'backup_integrity', 'integrity_checked_at']);
        });
    }
};
