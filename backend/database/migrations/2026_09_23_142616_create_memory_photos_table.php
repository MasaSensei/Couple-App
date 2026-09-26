<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('memory_photos', function (Blueprint $table) {
            $table->id();

            $table->foreignId('memory_id')
                ->constrained('memories')
                ->cascadeOnDelete();

            $table->foreignId('uploaded_by')
                ->constrained('users')
                ->cascadeOnDelete();

            /*
             * Opaque reference to the stored object.
             *
             * This must never be treated as a public URL.
             */
            $table->string('storage_key', 500);

            $table->string('original_filename', 255)
                ->nullable();

            $table->string('mime_type', 100);

            $table->unsignedBigInteger('file_size');

            $table->unsignedInteger('width')
                ->nullable();

            $table->unsignedInteger('height')
                ->nullable();

            /*
             * Integrity information.
             *
             * In Phase 4 this can represent the uploaded object's
             * checksum. Phase 5 can introduce encrypted checksum
             * semantics without changing the overall relationship.
             */
            $table->string('checksum', 128)
                ->nullable();

            /*
             * Reserved for Phase 5 encryption compatibility.
             *
             * No key management or encryption is implemented yet.
             */
            $table->string('encryption_version', 50)
                ->nullable();

            $table->unsignedBigInteger('encrypted_size')
                ->nullable();

            /*
             * pending   = upload session created
             * uploading = upload in progress
             * uploaded  = upload completed
             * verified  = integrity/metadata verification passed
             * failed    = upload/verification failed
             * deleted   = logical deletion
             */
            $table->string('status', 20)
                ->default('pending');

            $table->unsignedInteger('sort_order')
                ->default(0);

            $table->timestamps();
            $table->softDeletes();

            $table->index([
                'memory_id',
                'sort_order',
            ]);

            $table->index([
                'memory_id',
                'status',
            ]);

            $table->index('uploaded_by');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('memory_photos');
    }
};
