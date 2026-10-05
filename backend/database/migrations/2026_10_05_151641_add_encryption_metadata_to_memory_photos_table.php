<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('memory_photos', function (Blueprint $table) {
            $table->string(
                'encryption_algorithm',
                64,
            )->nullable()->after('encryption_version');

            $table->string(
                'key_id',
                128,
            )->nullable()->after('encryption_algorithm');

            $table->text(
                'nonce',
            )->nullable()->after('key_id');
        });
    }

    public function down(): void
    {
        Schema::table('memory_photos', function (Blueprint $table) {
            $table->dropColumn([
                'encryption_algorithm',
                'key_id',
                'nonce',
            ]);
        });
    }
};
