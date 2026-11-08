<?php

namespace Tests\Feature\Security;

use App\Models\AdminAuditLog;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/** Phase 9 hardening: rate limits, token lifecycle, headers, admin access. */
class ProductionHardeningTest extends TestCase
{
    use RefreshDatabase;

    // ── Rate limiting ────────────────────────────────────────────────────

    public function test_login_is_throttled_per_email_and_ip(): void
    {
        $user = User::factory()->create(['email' => 'alice@example.com']);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'wrong-password'])
                ->assertStatus(422);
        }

        $response = $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password']);

        $response->assertStatus(429)->assertJson(['success' => false]);
        $this->assertNotNull($response->headers->get('Retry-After'));
    }

    public function test_login_throttle_is_case_insensitive_on_email(): void
    {
        User::factory()->create(['email' => 'alice@example.com']);

        foreach (['alice@example.com', 'ALICE@example.com', 'Alice@Example.com', 'alice@EXAMPLE.com', 'aLice@example.com'] as $email) {
            $this->postJson('/api/v1/auth/login', ['email' => $email, 'password' => 'wrong'])->assertStatus(422);
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'alice@example.com', 'password' => 'wrong'])->assertStatus(429);
    }

    public function test_register_is_throttled_per_ip(): void
    {
        config(['security.rate_limits.auth_per_ip' => 3]);

        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/api/v1/auth/register', ['name' => 'x', 'email' => "u{$i}@example.com", 'password' => 'short', 'password_confirmation' => 'short'])
                ->assertStatus(422);
        }

        $this->postJson('/api/v1/auth/register', ['name' => 'x', 'email' => 'u9@example.com', 'password' => 'long-enough-1', 'password_confirmation' => 'long-enough-1'])
            ->assertStatus(429);
    }

    public function test_authenticated_api_is_throttled_per_user(): void
    {
        config(['security.rate_limits.api_per_user' => 2]);
        $token = User::factory()->create()->createToken('t')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/me')->assertOk();
        $this->withToken($token)->getJson('/api/v1/me')->assertOk();
        $this->withToken($token)->getJson('/api/v1/me')->assertStatus(429);
    }

    // ── Token lifecycle ──────────────────────────────────────────────────

    public function test_login_issues_an_expiring_token(): void
    {
        $user = User::factory()->create(['password' => 'password']);

        $response = $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password'])->assertOk();

        $expiresAt = $response->json('data.token_expires_at');
        $this->assertNotNull($expiresAt);
        $this->assertEqualsWithDelta(now()->addDays(60)->timestamp, strtotime($expiresAt), 5);
        $this->assertNotNull(PersonalAccessToken::first()->expires_at);
    }

    public function test_expired_token_is_rejected(): void
    {
        $user = User::factory()->create(['password' => 'password']);
        $token = $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password'])->json('data.token');

        $this->travel(61)->days();
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
    }

    public function test_refresh_rotates_the_token_and_keeps_the_device_binding(): void
    {
        $user = User::factory()->create();
        $device = UserDevice::create([
            'user_id' => $user->id,
            'device_identifier' => 'device-1',
            'platform' => 'android',
            'public_key' => base64_encode(random_bytes(32)),
        ]);
        $old = $user->createToken('flutter-app', ['*'], now()->addDays(3));
        $old->accessToken->forceFill(['user_device_id' => $device->id])->save();

        $response = $this->withToken($old->plainTextToken)->postJson('/api/v1/auth/refresh')->assertOk();
        $new = $response->json('data.token');

        $this->assertNotSame($old->plainTextToken, $new);
        $this->assertEqualsWithDelta(now()->addDays(60)->timestamp, strtotime($response->json('data.token_expires_at')), 5);
        $this->assertSame(1, PersonalAccessToken::count());
        $this->assertSame($device->id, PersonalAccessToken::first()->user_device_id);

        $this->app['auth']->forgetGuards();
        $this->withToken($old->plainTextToken)->getJson('/api/v1/me')->assertUnauthorized();
        $this->app['auth']->forgetGuards();
        $this->withToken($new)->getJson('/api/v1/me')->assertOk();
    }

    public function test_logout_all_revokes_every_session(): void
    {
        $user = User::factory()->create();
        $first = $user->createToken('a')->plainTextToken;
        $user->createToken('b');
        $other = User::factory()->create()->createToken('c');

        $this->withToken($first)->postJson('/api/v1/auth/logout-all')->assertOk()->assertJsonPath('data.revoked', 2);

        $this->assertSame(0, $user->tokens()->count());
        $this->assertSame(1, PersonalAccessToken::count(), 'Other users keep their sessions.');
        $this->assertNotNull(PersonalAccessToken::find($other->accessToken->id));
    }

    // ── Headers & error handling ─────────────────────────────────────────

    public function test_api_responses_carry_security_headers_and_a_request_id(): void
    {
        $response = $this->getJson('/api/v1/health')->assertOk();

        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('Referrer-Policy', 'no-referrer');
        $this->assertStringContainsString("default-src 'none'", $response->headers->get('Content-Security-Policy'));
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $this->assertMatchesRegularExpression('/^[0-9a-f-]{36}$/', $response->headers->get('X-Request-Id'));
    }

    public function test_a_well_formed_incoming_request_id_is_kept_and_a_malformed_one_replaced(): void
    {
        $this->getJson('/api/v1/health', ['X-Request-Id' => 'proxy-abc12345'])->assertHeader('X-Request-Id', 'proxy-abc12345');

        $replaced = $this->getJson('/api/v1/health', ['X-Request-Id' => "bad id\n<script>"])->headers->get('X-Request-Id');
        $this->assertMatchesRegularExpression('/^[0-9a-f-]{36}$/', $replaced);
    }

    public function test_unexpected_errors_hide_details_and_return_the_request_id(): void
    {
        config(['app.debug' => false]);
        Route::get('/api/v1/_test/boom', fn () => throw new \RuntimeException('SQLSTATE secret detail /var/www/html'));

        $response = $this->getJson('/api/v1/_test/boom', ['X-Request-Id' => 'trace-12345678']);

        $response->assertStatus(500)->assertJsonPath('data.request_id', 'trace-12345678');
        $this->assertStringNotContainsString('SQLSTATE', $response->getContent());
        $this->assertStringNotContainsString('/var/www', $response->getContent());
    }

    public function test_hsts_is_only_sent_over_https_in_production(): void
    {
        $this->getJson('/api/v1/health')->assertHeaderMissing('Strict-Transport-Security');

        $this->app['env'] = 'production';
        $this->getJson('https://localhost/api/v1/health')->assertHeader('Strict-Transport-Security');
    }

    // ── Admin panel ──────────────────────────────────────────────────────

    public function test_admin_without_mfa_is_sent_to_mfa_setup_when_required(): void
    {
        config(['security.admin.mfa_required' => true]);
        $admin = User::factory()->create(['is_admin' => true]);
        $admin->saveAppAuthenticationSecret(null);

        $response = $this->actingAs($admin)->get('/admin');

        $response->assertRedirect();
        $this->assertStringContainsString('multi-factor', (string) $response->headers->get('Location'));
    }

    public function test_admin_with_mfa_enrolled_reaches_the_panel(): void
    {
        config(['security.admin.mfa_required' => true]);
        $admin = User::factory()->create(['is_admin' => true]);
        $admin->saveAppAuthenticationSecret('JBSWY3DPEHPK3PXP');

        $this->actingAs($admin)->get('/admin')->assertOk();
        $this->assertNotSame('JBSWY3DPEHPK3PXP', $admin->getRawOriginal('app_authentication_secret'), 'Secret is encrypted at rest.');
    }

    public function test_admin_ip_allowlist_hides_the_panel_from_other_ips(): void
    {
        config(['security.admin.allowed_ips' => ['10.0.0.0/8']]);

        $this->get('/admin/login')->assertNotFound();

        $this->withServerVariables(['REMOTE_ADDR' => '10.1.2.3'])->get('/admin/login')->assertOk();
    }

    public function test_admin_role_is_granted_and_revoked_only_by_cli(): void
    {
        $user = User::factory()->create(['email' => 'ops@example.com']);

        $this->artisan('admin:role', ['action' => 'grant', 'email' => 'ops@example.com'])->assertSuccessful();
        $this->assertTrue($user->fresh()->is_admin);

        $user->fresh()->forceFill(['admin_permissions' => ['billing.view']])->save();
        $user->fresh()->saveAppAuthenticationSecret('JBSWY3DPEHPK3PXP');

        $this->artisan('admin:role', ['action' => 'revoke', 'email' => 'ops@example.com'])->assertSuccessful();
        $user = $user->fresh();
        $this->assertFalse($user->is_admin);
        $this->assertSame([], $user->admin_permissions);
        $this->assertNull($user->app_authentication_secret);
        $this->assertSame(2, AdminAuditLog::where('subject_id', $user->id)->count());
    }

    public function test_user_payload_never_contains_mfa_secrets(): void
    {
        $user = User::factory()->create(['is_admin' => true]);
        $user->saveAppAuthenticationSecret('JBSWY3DPEHPK3PXP');

        $this->assertArrayNotHasKey('app_authentication_secret', $user->fresh()->toArray());
    }
}
