<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** Optional anniversary the couple sets themselves ("Together N days"). */
    public function up(): void
    {
        Schema::table('couples', function (Blueprint $table) {
            $table->date('relationship_started_at')->nullable()->after('invite_code');
        });
    }

    public function down(): void
    {
        Schema::table('couples', function (Blueprint $table) {
            $table->dropColumn('relationship_started_at');
        });
    }
};
