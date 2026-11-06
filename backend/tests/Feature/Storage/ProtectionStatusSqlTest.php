<?php

namespace Tests\Feature\Storage;

use App\Models\Couple;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** MemoryPhoto::protectionStatusSql() must agree with protectionStatus() for every state. */
class ProtectionStatusSqlTest extends TestCase
{
    use RefreshDatabase;

    public function test_sql_and_php_agree_on_every_combination(): void
    {
        $memory = Memory::factory()->create([
            'couple_id' => Couple::factory()->create()->id,
            'created_by' => User::factory()->create()->id,
        ]);

        $combinations = 0;

        foreach (['pending', 'uploading', 'verified', 'failed'] as $status) {
            foreach ([null, 'pending', 'verified', 'failed'] as $backup) {
                foreach ([null, 'ok', 'mismatch', 'missing'] as $primaryIntegrity) {
                    foreach ([null, 'ok', 'missing'] as $backupIntegrity) {
                        foreach ([null, 'pending', 'failed'] as $repair) {
                            foreach ([null, '', 'mac'] as $mac) {
                                foreach ([false, true] as $trashed) {
                                    (new MemoryPhoto)->forceFill([
                                        'memory_id' => $memory->id,
                                        'storage_key' => 'k/'.$combinations++,
                                        'mime_type' => 'image/jpeg',
                                        'file_size' => 1,
                                        'checksum' => 'c', 'encryption_version' => '1', 'key_id' => 'k', 'nonce' => 'n',
                                        'mac' => $mac,
                                        'status' => $status,
                                        'backup_status' => $backup,
                                        'primary_integrity' => $primaryIntegrity,
                                        'backup_integrity' => $backupIntegrity,
                                        'repair_status' => $repair,
                                        'deleted_at' => $trashed ? now() : null,
                                    ])->save();
                                }
                            }
                        }
                    }
                }
            }
        }

        $sql = MemoryPhoto::withTrashed()
            ->selectRaw('id, '.MemoryPhoto::protectionStatusSql().' AS protection')
            ->pluck('protection', 'id');

        $mismatches = MemoryPhoto::withTrashed()->get()
            ->filter(fn (MemoryPhoto $photo) => $photo->protectionStatus() !== $sql[$photo->id])
            ->map(fn (MemoryPhoto $photo) => "#{$photo->id}: php={$photo->protectionStatus()} sql={$sql[$photo->id]}")
            ->values()
            ->all();

        $this->assertSame([], $mismatches);
        $this->assertSame($combinations, $sql->count());

        $counts = MemoryPhoto::protectionCounts(MemoryPhoto::query());
        $this->assertSame($combinations, array_sum($counts));
    }
}
