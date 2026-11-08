<?php

namespace Tests\Feature\Api\V1\Appearance;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\CoupleThemeSetting;
use App\Models\PhotoBoothTemplate;
use App\Models\Theme;
use App\Models\User;
use App\Services\Appearance\AppearanceCatalog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CoupleThemeTest extends TestCase
{
    use RefreshDatabase;

    private User $alice;

    private User $bob;

    private Couple $couple;

    protected function setUp(): void
    {
        parent::setUp();

        [$this->alice, $this->bob, $this->couple] = $this->couple();
    }

    private function couple(): array
    {
        $couple = Couple::factory()->create();
        $a = User::factory()->create();
        $b = User::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $a->id]);
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $b->id]);

        return [$a, $b, $couple];
    }

    private function putTheme(User $user, array $body)
    {
        return $this->actingAs($user)->putJson('/api/v1/couple/theme', $body);
    }

    public function test_catalog_lists_the_selectable_themes_and_templates_from_the_app_definitions(): void
    {
        $response = $this->actingAs($this->alice)->getJson('/api/v1/appearance/catalog')->assertOk();

        $this->assertSame(
            ['classic_rose', 'sakura', 'winter_love', 'midnight', 'vintage_film', 'imperial_winter', 'cottage', 'cafe', 'starry_night'],
            $response->json('data.themes.*.key'),
        );
        $this->assertCount(8, $response->json('data.photo_booth_templates'));
        $this->assertSame(['rose', 'plum', 'coral'], $response->json('data.themes.1.options.accents'));
    }

    public function test_hidden_items_leave_the_catalog_and_sync_never_overrides_admin_choices(): void
    {
        Theme::where('key', 'cafe')->update(['status' => 'hidden', 'is_premium' => true, 'sort_order' => 99]);
        PhotoBoothTemplate::where('key', 'polaroid')->update(['status' => 'retired']);

        app(AppearanceCatalog::class)->sync();

        $response = $this->actingAs($this->alice)->getJson('/api/v1/appearance/catalog');
        $this->assertNotContains('cafe', $response->json('data.themes.*.key'));
        $this->assertNotContains('polaroid', $response->json('data.photo_booth_templates.*.key'));
        $cafe = Theme::where('key', 'cafe')->first();
        $this->assertSame(['hidden', true, 99], [$cafe->status, $cafe->is_premium, $cafe->sort_order]);
        $this->assertSame(9, Theme::count());
    }

    public function test_new_couple_gets_the_default_theme_at_version_zero(): void
    {
        $this->actingAs($this->alice)->getJson('/api/v1/couple/theme')
            ->assertOk()
            ->assertJsonPath('data.theme.theme_key', 'classic_rose')
            ->assertJsonPath('data.theme.version', 0);
    }

    public function test_applied_theme_is_shared_with_the_partner(): void
    {
        $this->putTheme($this->alice, [
            'theme_key' => 'sakura',
            'customization' => ['accent' => 'plum', 'decorations' => false, 'memory_style' => 'polaroid'],
            'version' => 0,
        ])->assertOk()->assertJsonPath('data.theme.version', 1);

        $this->actingAs($this->bob)->getJson('/api/v1/couple/theme')
            ->assertJsonPath('data.theme.theme_key', 'sakura')
            ->assertJsonPath('data.theme.customization.accent', 'plum')
            ->assertJsonPath('data.theme.customization.decorations', false)
            ->assertJsonPath('data.theme.updated_by', $this->alice->id)
            ->assertJsonPath('data.theme.version', 1);
    }

    public function test_concurrent_update_is_rejected_with_the_current_settings(): void
    {
        // Both partners loaded version 0.
        $this->putTheme($this->alice, ['theme_key' => 'sakura', 'customization' => [], 'version' => 0])->assertOk();

        $this->putTheme($this->bob, ['theme_key' => 'midnight', 'customization' => [], 'version' => 0])
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('data.theme.theme_key', 'sakura')
            ->assertJsonPath('data.theme.version', 1);

        // Bob saw the conflict and chooses again on top of version 1.
        $this->putTheme($this->bob, ['theme_key' => 'midnight', 'customization' => [], 'version' => 1])
            ->assertOk()->assertJsonPath('data.theme.version', 2);

        // A stale update (version 1) after that is rejected too; nothing was overwritten.
        $this->putTheme($this->alice, ['theme_key' => 'cafe', 'customization' => [], 'version' => 1])->assertStatus(409);
        $this->assertSame('midnight', CoupleThemeSetting::first()->theme_key);
        $this->assertSame(1, CoupleThemeSetting::count());
    }

    public function test_customization_is_validated_against_the_themes_presets(): void
    {
        foreach ([
            ['accent' => '#ff00ff'],
            ['accent' => 'ice'], // belongs to Winter Love, not Sakura
            ['font' => 'ComicSans'],
            ['decorations' => 'yes'],
            ['memory_style' => 'neon'],
            ['css' => 'body{display:none}'],
        ] as $customization) {
            $this->putTheme($this->alice, ['theme_key' => 'sakura', 'customization' => $customization, 'version' => 0])
                ->assertUnprocessable();
        }

        $this->assertSame(0, CoupleThemeSetting::count());
    }

    public function test_unknown_and_unavailable_themes_are_rejected(): void
    {
        $this->putTheme($this->alice, ['theme_key' => 'hacker_green', 'customization' => [], 'version' => 0])->assertUnprocessable();

        Theme::where('key', 'cafe')->update(['status' => 'hidden']);
        $this->putTheme($this->alice, ['theme_key' => 'cafe', 'customization' => [], 'version' => 0])->assertUnprocessable();
    }

    public function test_a_couple_keeps_a_theme_that_was_hidden_later_and_can_still_customize_it(): void
    {
        $this->putTheme($this->alice, ['theme_key' => 'cafe', 'customization' => [], 'version' => 0])->assertOk();
        Theme::where('key', 'cafe')->update(['status' => 'hidden']);

        $this->actingAs($this->bob)->getJson('/api/v1/couple/theme')->assertJsonPath('data.theme.theme_key', 'cafe');
        $this->putTheme($this->bob, ['theme_key' => 'cafe', 'customization' => ['accent' => 'mocha'], 'version' => 1])->assertOk();
    }

    public function test_reset_returns_to_the_theme_defaults_and_keeps_the_theme(): void
    {
        $this->putTheme($this->alice, ['theme_key' => 'cottage', 'customization' => ['accent' => 'terracotta', 'animations' => false], 'version' => 0]);

        $this->actingAs($this->bob)->deleteJson('/api/v1/couple/theme/customization', ['version' => 1])
            ->assertOk()
            ->assertJsonPath('data.theme.theme_key', 'cottage')
            ->assertJsonPath('data.theme.customization', [])
            ->assertJsonPath('data.theme.version', 2);

        $this->actingAs($this->alice)->deleteJson('/api/v1/couple/theme/customization', ['version' => 1])->assertStatus(409);
    }

    public function test_default_values_are_not_stored(): void
    {
        $this->putTheme($this->alice, [
            'theme_key' => 'sakura',
            'customization' => ['decorations' => true, 'animations' => true, 'couple_space_style' => 'classic', 'memory_style' => 'soft'],
            'version' => 0,
        ])->assertOk()->assertJsonPath('data.theme.customization', []);
    }

    public function test_outsiders_cannot_read_or_change_another_couples_theme(): void
    {
        $this->putTheme($this->alice, ['theme_key' => 'sakura', 'customization' => [], 'version' => 0]);
        [$carol] = $this->couple();

        // Carol only ever reaches her own couple's settings.
        $this->actingAs($carol)->getJson('/api/v1/couple/theme')->assertJsonPath('data.theme.theme_key', 'classic_rose');
        $this->putTheme($carol, ['theme_key' => 'midnight', 'customization' => [], 'version' => 0])->assertOk();
        $this->actingAs($this->alice)->getJson('/api/v1/couple/theme')->assertJsonPath('data.theme.theme_key', 'sakura');

        $single = User::factory()->create();
        $this->actingAs($single)->getJson('/api/v1/couple/theme')->assertNotFound();
        $this->putTheme($single, ['theme_key' => 'midnight', 'customization' => [], 'version' => 0])->assertNotFound();
    }

    public function test_guests_cannot_read_or_change_any_theme(): void
    {
        $this->getJson('/api/v1/couple/theme')->assertUnauthorized();
        $this->putJson('/api/v1/couple/theme', ['theme_key' => 'sakura', 'customization' => [], 'version' => 0])->assertUnauthorized();
    }

    public function test_admin_theme_pages_are_admin_only_and_have_no_delete(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $theme = Theme::where('key', 'sakura')->first();

        $this->actingAs($admin)->get('/admin/themes')->assertOk()->assertSee('sakura');
        $this->actingAs($admin)->get("/admin/themes/{$theme->id}/edit")->assertOk();
        $this->actingAs($admin)->get('/admin/photo-booth-templates')->assertOk()->assertSee('polaroid');
        $this->actingAs($this->alice)->get('/admin/themes')->assertForbidden();
    }
}
