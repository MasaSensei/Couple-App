<?php

namespace Tests\Feature\Admin;

use App\Filament\Resources\Couples\Tables\CouplesTable;
use App\Filament\Support\StatusColors;
use App\Filament\Widgets\PlatformOverview;
use App\Filament\Widgets\RecentOperatorActivity;
use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

/** Admin redesign: branding, real dashboard data, privacy of admin screens. */
class AdminRedesignTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        config(['security.admin.mfa_required' => false]);
        $this->admin = User::factory()->create(['is_admin' => true, 'name' => 'Ops Admin']);
    }

    public function test_panel_uses_brand_assets_and_no_external_font_cdn(): void
    {
        $html = $this->actingAs($this->admin)->get('/admin')->assertOk()->getContent();

        $this->assertStringContainsString('brand/brand.css', $html);
        $this->assertStringContainsString('brand/favicon.svg', $html);
        $this->assertStringContainsString('ols-brand', $html);
        $this->assertStringNotContainsString('fonts.bunny.net', $html);
        $this->assertStringNotContainsString('fonts.googleapis.com', $html);
        // The Filament promo widget is gone; real widgets are shown.
        $this->assertStringNotContainsString('filament-info-widget', $html);
    }

    public function test_brand_assets_exist_with_font_licenses(): void
    {
        foreach (['brand.css', 'favicon.svg', 'fonts/Nunito.ttf', 'fonts/PlayfairDisplay.ttf', 'fonts/OFL-nunito.txt', 'fonts/OFL-playfairdisplay.txt'] as $file) {
            $this->assertFileExists(public_path("brand/{$file}"));
        }
    }

    public function test_sidebar_groups_resources_logically(): void
    {
        $html = $this->actingAs($this->admin)->get('/admin')->assertOk()->getContent();

        foreach (['People', 'Content &amp; appearance', 'Storage &amp; backups', 'Users', 'Couples', 'Photo storage'] as $label) {
            $this->assertStringContainsString($label, $html, $label);
        }
    }

    public function test_platform_overview_shows_real_counts(): void
    {
        $complete = Couple::create();
        foreach (User::factory()->count(2)->create() as $u) {
            CoupleMember::create(['couple_id' => $complete->id, 'user_id' => $u->id]);
        }
        $waiting = Couple::create();
        CoupleMember::create(['couple_id' => $waiting->id, 'user_id' => User::factory()->create()->id]);

        $this->actingAs($this->admin);

        // 1 admin + 3 members = 4 users; 2 couples, 1 complete.
        Livewire::test(PlatformOverview::class)
            ->assertSee('Users')
            ->assertSee('4')
            ->assertSee('Couples')
            ->assertSee('1 with both partners')
            ->assertSee('1 waiting')
            // Billing numbers need billing.view, not just admin.
            ->assertDontSee('Active subscriptions');
    }

    public function test_billing_stat_appears_with_billing_permission(): void
    {
        $this->admin->forceFill(['admin_permissions' => ['billing.view']])->save();
        $this->actingAs($this->admin);

        Livewire::test(PlatformOverview::class)->assertSee('Active subscriptions');
    }

    public function test_recent_activity_lists_operator_actions_with_admin_email(): void
    {
        PhotoStorageAudit::record(null, 'admin_retry_backup', 'queued', "user:{$this->admin->id}");
        PhotoStorageAudit::record(null, 'verify', 'succeeded', 'scheduler');

        $this->actingAs($this->admin);

        Livewire::test(RecentOperatorActivity::class)
            ->assertSee('Retry backup')
            ->assertSee($this->admin->email)
            ->assertDontSee('scheduler');
    }

    public function test_couple_screens_mask_the_invite_code(): void
    {
        $couple = Couple::create(['invite_code' => 'ABCD1234']);
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => User::factory()->create()->id]);

        $this->assertSame('••••••34', CouplesTable::maskInviteCode('ABCD1234'));

        $this->actingAs($this->admin);
        $list = $this->get('/admin/couples')->assertOk()->getContent();
        $view = $this->get("/admin/couples/{$couple->id}")->assertOk()->getContent();

        $this->assertStringNotContainsString('ABCD1234', $list);
        $this->assertStringNotContainsString('ABCD1234', $view);
        $this->assertStringContainsString('Waiting for partner', $view);
    }

    public function test_user_pages_render_with_sections_and_title(): void
    {
        $user = User::factory()->create(['name' => 'Nadia Example']);

        $this->actingAs($this->admin);
        $this->get('/admin/users')->assertOk()->assertSee('Nadia Example');
        $this->get("/admin/users/{$user->id}")->assertOk()
            ->assertSee('Profile')
            ->assertSee('Activity')
            ->assertSee('Not in a couple');
    }

    public function test_status_colours_are_consistent_and_protected_means_verified_backup(): void
    {
        $this->assertSame('success', StatusColors::for('protected'));
        $this->assertSame('info', StatusColors::for('backup_pending'));
        $this->assertSame('danger', StatusColors::for('degraded'));
        $this->assertSame('danger', StatusColors::for('failed'));
        $this->assertSame('gray', StatusColors::for('something_new'));
        $this->assertSame('Grace period', StatusColors::label('grace_period'));
    }

    public function test_non_admin_still_cannot_open_the_panel(): void
    {
        $user = User::factory()->create(['is_admin' => false]);

        $this->actingAs($user)->get('/admin')->assertForbidden();
    }
}
