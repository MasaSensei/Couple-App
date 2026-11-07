<?php

namespace Tests\Feature\Performance;

use App\Models\Date;
use App\Models\Memory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Feature\Billing\BillingHelpers;
use Tests\TestCase;

/**
 * N+1 guard: list endpoints must run the same number of queries whether a
 * couple has 2 or 20 items. A failure here means a relation is lazy-loaded
 * per row.
 */
class QueryBudgetTest extends TestCase
{
    use BillingHelpers, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
        $this->seedPlans();
    }

    private function queriesFor(callable $request): int
    {
        $count = 0;
        DB::listen(function () use (&$count) {
            $count++;
        });
        $request();
        DB::flushQueryLog();

        return $count;
    }

    /** @return array{0: int, 1: int} query counts for a small and a large couple */
    private function measure(string $uri, callable $seed): array
    {
        $counts = [];

        foreach ([2, 20] as $size) {
            [$alice, , $couple] = $this->makeCouple();
            $seed($couple, $alice, $size);
            $this->app['auth']->forgetGuards();

            $counts[] = $this->queriesFor(fn () => $this->actingAs($alice)->getJson($uri)->assertOk());
        }

        return $counts;
    }

    public function test_memory_list_is_constant(): void
    {
        [$small, $large] = $this->measure('/api/v1/memories', function ($couple, $user, $n) {
            Memory::factory()->count($n)->create(['couple_id' => $couple->id, 'created_by' => $user->id]);
        });

        $this->assertSame($small, $large, "GET /memories: {$small} queries for 2 items, {$large} for 20.");
    }

    public function test_memory_timeline_is_constant(): void
    {
        [$small, $large] = $this->measure('/api/v1/memories/timeline', function ($couple, $user, $n) {
            Memory::factory()->count($n)->create(['couple_id' => $couple->id, 'created_by' => $user->id]);
        });

        $this->assertSame($small, $large, "GET /memories/timeline: {$small} vs {$large} queries.");
    }

    public function test_date_list_is_constant(): void
    {
        [$small, $large] = $this->measure('/api/v1/dates', function ($couple, $user, $n) {
            Date::factory()->count($n)->create(['couple_id' => $couple->id, 'created_by' => $user->id]);
        });

        $this->assertSame($small, $large, "GET /dates: {$small} vs {$large} queries.");
    }

    public function test_photo_list_of_a_memory_is_constant(): void
    {
        $counts = [];

        foreach ([2, 20] as $n) {
            [$alice, , $couple] = $this->makeCouple();
            for ($i = 0; $i < $n; $i++) {
                $photo = $this->photo($couple, $alice, 1000);
            }
            $this->app['auth']->forgetGuards();
            $counts[] = $this->queriesFor(fn () => $this->actingAs($alice)->getJson("/api/v1/memories/{$photo->memory_id}/photos")->assertOk());
        }

        $this->assertSame($counts[0], $counts[1], "GET /memories/{id}/photos: {$counts[0]} vs {$counts[1]} queries.");
    }
}
