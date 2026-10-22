<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            // Binds an API token to the device that registered with it,
            // so revoking the device also revokes its tokens.
            $table->foreignId('user_device_id')
                ->nullable()
                ->constrained('user_devices')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_device_id');
        });
    }
};
