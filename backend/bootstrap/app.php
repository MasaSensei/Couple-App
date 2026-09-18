<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Auth\Access\AuthorizationException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        commands: __DIR__ . '/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->redirectGuestsTo(function (Request $request) {
            if ($request->is('api/*')) {
                return null;
            }

            return route('login');
        });
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn(Request $request) =>
            $request->is('api/*') || $request->expectsJson(),
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
                return response()->json([
                    'success' => false,
                    'message' => $e->getMessage() ?: 'An error occurred.',
                    'data' => null,
                ], $e->getStatusCode());
            }
        });

        // 422 - Business rule
        $exceptions->render(function (
            \DomainException $e,
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
            \Throwable $e,
            Request $request
        ) {
            if ($request->is('api/*')) {
                return response()->json([
                    'success' => false,
                    'message' => 'Something went wrong.',
                    'data' => null,
                ], Response::HTTP_INTERNAL_SERVER_ERROR);
            }
        });
    })
    ->create();
