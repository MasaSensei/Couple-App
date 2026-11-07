<?php

namespace Tests\Feature\Ops;

use App\Logging\RedactSensitiveData;
use App\Models\PaymentWebhookEvent;
use App\Services\Ops\Heartbeat;
use App\Services\Ops\OpsAlerts;
use App\Services\Storage\PhotoStorage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Mockery;
use Monolog\Level;
use Monolog\LogRecord;
use Tests\TestCase;

/** Phase 9: health checks, heartbeats, alert routing, structured & redacted logs. */
class ObservabilityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
    }

    private function beatAll(): void
    {
        foreach (Heartbeat::COMPONENTS as $component) {
            app(Heartbeat::class)->beat($component);
        }
    }

    // ── Health ───────────────────────────────────────────────────────────

    public function test_ready_is_ok_when_dependencies_and_heartbeats_are_fresh(): void
    {
        $this->beatAll();

        $this->getJson('/api/v1/health/ready')->assertOk()->assertExactJson(['status' => 'ok']);
    }

    public function test_ready_fails_when_the_scheduler_has_stopped(): void
    {
        $this->beatAll();
        $this->travel(10)->minutes();

        $this->getJson('/api/v1/health/ready')->assertStatus(503)->assertExactJson(['status' => 'fail']);
    }

    public function test_ready_details_require_the_health_token(): void
    {
        config(['observability.health_token' => 'health-secret']);
        $this->beatAll();
        $this->app->instance('photos.backup', $broken = Mockery::mock(PhotoStorage::class));
        $broken->shouldReceive('listKeys')->andThrow(new \RuntimeException('connect to https://user:pass@s3.example failed'));

        $this->getJson('/api/v1/health/ready')->assertStatus(503)->assertExactJson(['status' => 'fail']);
        $this->getJson('/api/v1/health/ready', ['Authorization' => 'Bearer wrong'])->assertExactJson(['status' => 'fail']);

        $detailed = $this->getJson('/api/v1/health/ready', ['Authorization' => 'Bearer health-secret'])->assertStatus(503);
        $detailed->assertJsonPath('checks.database.ok', true)
            ->assertJsonPath('checks.storage_backup.ok', false)
            ->assertJsonPath('checks.storage_backup.detail', 'RuntimeException');
        $this->assertStringNotContainsString('user:pass', $detailed->getContent(), 'Connection strings never leak.');
    }

    public function test_ready_does_not_depend_on_the_cache(): void
    {
        $this->beatAll();
        $store = Mockery::mock();
        $store->shouldReceive(Mockery::any())->andThrow(new \RuntimeException('Connection refused'));
        Cache::swap($store);

        $this->getJson('/api/v1/health/ready')->assertOk();
    }

    public function test_liveness_touches_no_dependency(): void
    {
        DB::shouldReceive('select')->never();

        $this->getJson('/api/v1/health')->assertOk();
    }

    // ── Heartbeats ───────────────────────────────────────────────────────

    public function test_heartbeat_command_records_scheduler_and_queue_and_pings_monitors(): void
    {
        config(['observability.heartbeat_urls' => ['scheduler' => 'https://hc.example/s', 'queue' => 'https://hc.example/q']]);
        Http::fake();

        $this->artisan('ops:heartbeat')->assertSuccessful(); // queue is sync in tests: the job runs inline

        $this->assertFalse(app(Heartbeat::class)->isStale('scheduler'));
        $this->assertFalse(app(Heartbeat::class)->isStale('queue'));
        Http::assertSent(fn ($request) => $request->url() === 'https://hc.example/s');
        Http::assertSent(fn ($request) => $request->url() === 'https://hc.example/q');
    }

    public function test_an_unreachable_heartbeat_monitor_does_not_break_the_heartbeat(): void
    {
        config(['observability.heartbeat_urls.scheduler' => 'https://hc.example/s']);
        Http::fake(fn () => throw new ConnectionException('down'));

        app(Heartbeat::class)->beat('scheduler');

        $this->assertFalse(app(Heartbeat::class)->isStale('scheduler'));
    }

    // ── Alerts ───────────────────────────────────────────────────────────

    public function test_stopped_scheduler_and_stuck_webhooks_raise_alerts(): void
    {
        $this->beatAll();
        PaymentWebhookEvent::forceCreate([
            'provider' => 'mock', 'event_id' => 'e1', 'event_type' => 'renewed', 'status' => 'failed',
            'payload' => [], 'created_at' => now()->subHour(),
        ]);
        $this->travel(10)->minutes();

        $codes = collect(app(OpsAlerts::class)->current())->pluck('code');

        $this->assertContains('scheduler_down', $codes);
        $this->assertContains('webhook_stuck', $codes);
    }

    public function test_alerts_are_still_sent_when_the_cache_is_down(): void
    {
        $this->travel(10)->minutes(); // no heartbeat at all → critical

        $store = Mockery::mock();
        $store->shouldReceive('get', 'add', 'forget', 'forever')->andThrow(new \RuntimeException('Connection refused [tcp://redis:6379]'));
        Cache::swap($store);

        $channel = Mockery::mock();
        $channel->shouldReceive('critical')->withArgs(fn ($message) => str_contains($message, 'scheduler'))->atLeast()->once();
        $channel->shouldReceive('critical', 'warning', 'notice');
        Log::shouldReceive('channel')->with('alerts')->andReturn($channel);
        Log::shouldReceive('error', 'warning', 'log');

        $this->artisan('ops:alerts')->assertFailed();
    }

    // ── Logging ──────────────────────────────────────────────────────────

    public function test_log_redaction_removes_secrets_from_context_and_messages(): void
    {
        $record = new LogRecord(
            datetime: new \DateTimeImmutable,
            channel: 'test',
            level: Level::Warning,
            message: 'Call failed with Bearer 12|abcdefghijABCDEFGHIJabcdefghijABCDEFGHIJxyz and key ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567-ABCD-EFGH-IJKL-MNOP-QRST',
            context: [
                'password' => 'hunter2',
                'nested' => ['access_token' => 't0k3n', 'recovery_key' => 'rk', 'wrapped_couple_key' => 'w', 'count' => 3],
                'headers' => ['Authorization' => 'Bearer zzz'],
                'url' => 'https://x.test/?token=abc&page=2',
            ],
            extra: ['request_id' => 'req-12345678'],
        );

        $clean = (new RedactSensitiveData)($record);
        $flat = json_encode([$clean->message, $clean->context, $clean->extra]);

        foreach (['hunter2', 't0k3n', '"rk"', 'abcdefghijABCDEFGHIJ', 'zzz', 'ABCD-EFGH-IJKL', 'token=abc'] as $secret) {
            $this->assertStringNotContainsString($secret, $flat, "Leaked: {$secret}");
        }
        $this->assertSame(3, $clean->context['nested']['count']);
        $this->assertSame('req-12345678', $clean->extra['request_id']);
    }

    public function test_every_api_request_is_logged_with_route_status_and_duration(): void
    {
        Log::spy();

        $this->getJson('/api/v1/health', ['X-Request-Id' => 'req-abcdefgh'])->assertOk();

        Log::shouldHaveReceived('info')->with('http.request', Mockery::on(fn (array $context) => $context['route'] === 'api/v1/health'
            && $context['status'] === 200
            && is_int($context['duration_ms'])
            && $context['auth_failure'] === false))->once();
    }

    public function test_failed_logins_are_logged_without_the_email_or_password(): void
    {
        Log::spy();

        $this->postJson('/api/v1/auth/login', ['email' => 'Victim@Example.com', 'password' => 'guess-1'])->assertStatus(422);

        Log::shouldHaveReceived('warning')->with('auth.login_failed', Mockery::on(fn (array $context) => strlen($context['email_hash']) === 16
            && ! str_contains(json_encode($context), 'Victim')
            && ! str_contains(json_encode($context), 'guess-1')))->once();
    }
}
