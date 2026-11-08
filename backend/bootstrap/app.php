<?php

use App\Http\Middleware\AssignRequestId;
use App\Http\Middleware\LogRequest;
use App\Http\Middleware\SecurityHeaders;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Context;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Comma-separated proxy IPs/CIDRs (or "*" behind a private load balancer).
        // Read from the real environment so it also works with config:cache.
        $proxies = env('TRUSTED_PROXIES');
        if (filled($proxies)) {
            $middleware->trustProxies(at: $proxies === '*' ? '*' : array_map('trim', explode(',', $proxies)));
        }

        $middleware->prepend(AssignRequestId::class);
        $middleware->append(SecurityHeaders::class);
        $middleware->append(LogRequest::class);

        $middleware->redirectGuestsTo(function (Request $request) {
            if ($request->is('api/*')) {
                return null;
            }

            return route('login');
        });
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // 401 - Authentication
        $exceptions->render(function (
            AuthenticationException $e,
            Request $request
        ) {
            if ($request->is('api/*')) {
                return response()->json([
                    'success' => false,
                    'message' => 'Unauthenticated.',
                    'data' => null,
                ], Response::HTTP_UNAUTHORIZED);
            }
        });

        $exceptions->render(function (
            AuthorizationException $e,
            Request $request
        ) {
            if ($request->is('api/*')) {
                return response()->json([
                    'success' => false,
                    'message' => 'This action is unauthorized.',
                    'data' => null,
                ], Response::HTTP_FORBIDDEN);
            }
        });

        $exceptions->render(function (
            HttpExceptionInterface $e,
            Request $request
        ) {
            if ($request->is('api/*')) {
                // Keep Retry-After & co. on 429/503 responses.
                return response()->json([
                    'success' => false,
                    'message' => $e->getMessage() ?: 'An error occurred.',
                    'data' => null,
                ], $e->getStatusCode(), $e->getHeaders());
            }
        });

        // 422 - Business rule
        $exceptions->render(function (
            DomainException $e,
            Request $request
        ) {
            if ($request->is('api/*')) {
                return response()->json([
                    'success' => false,
                    'message' => $e->getMessage(),
                    'data' => null,
                ], Response::HTTP_UNPROCESSABLE_ENTITY);
            }
        });

        // 422 - Validation
        $exceptions->render(function (
            ValidationException $e,
            Request $request
        ) {
            if ($request->is('api/*')) {
                return response()->json([
                    'success' => false,
                    'message' => 'The given data was invalid.',
                    'data' => [
                        'errors' => $e->errors(),
                    ],
                ], Response::HTTP_UNPROCESSABLE_ENTITY);
            }
        });

        // 500 - Unexpected error
        $exceptions->render(function (
            Throwable $e,
            Request $request
        ) {
            if ($request->is('api/*')) {
                // Never expose exception details; the request id lets support find the log entry.
                return response()->json([
                    'success' => false,
                    'message' => 'Something went wrong.',
                    'data' => ['request_id' => Context::get('request_id')],
                ], Response::HTTP_INTERNAL_SERVER_ERROR);
            }
        });
    })
    ->create();
