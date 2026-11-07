<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Account deletion (docs/operations/account-deletion.md): a date planned by one
// partner belongs to the couple, so it must survive that partner deleting
// their account, like memories already do. created_by becomes nullable and is
// set to NULL instead of cascading the delete.
//
// Safe on a live database: only relaxes a constraint, no data rewrite.
// down() restores NOT NULL and fails if anonymised rows exist — intended:
// those rows must be handled deliberately, never dropped by a rollback.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('dates', function (Blueprint $table) {
            $table->dropForeign(['created_by']);
        });

        Schema::table('dates', function (Blueprint $table) {
            $table->unsignedBigInteger('created_by')->nullable()->change();
            $table->foreign('created_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('dates', function (Blueprint $table) {
            $table->dropForeign(['created_by']);
        });

        Schema::table('dates', function (Blueprint $table) {
            $table->unsignedBigInteger('created_by')->nullable(false)->change();
            $table->foreign('created_by')->references('id')->on('users')->cascadeOnDelete();
        });
    }
};
