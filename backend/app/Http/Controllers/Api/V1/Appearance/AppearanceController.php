<?php

namespace App\Http\Controllers\Api\V1\Appearance;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Appearance\ResetCoupleThemeCustomizationRequest;
use App\Http\Requests\Api\V1\Appearance\UpdateCoupleThemeRequest;
use App\Http\Responses\ApiResponse;
use App\Models\PhotoBoothTemplate;
use App\Models\Theme;
use App\Services\Appearance\CoupleThemeService;
use App\Services\Appearance\ThemeVersionConflict;
use App\Services\MemoryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class AppearanceController extends Controller
{
    public function __construct(
        private readonly CoupleThemeService $themes,
        private readonly MemoryService $memoryService,
    ) {}

    /** Selectable themes and Photo Booth templates (metadata only). */
    public function catalog(): JsonResponse
    {
        return ApiResponse::success('Appearance catalog retrieved successfully.', [
            'themes' => Theme::selectable()->get()->map(fn (Theme $theme) => [
                'key' => $theme->key,
                'name' => $theme->name,
                'version' => $theme->version,
                'is_default' => $theme->is_default,
                'is_premium' => $theme->is_premium,
                'options' => $theme->options,
            ]),
            'photo_booth_templates' => PhotoBoothTemplate::selectable()->get()->map(fn (PhotoBoothTemplate $template) => [
                'key' => $template->key,
                'name' => $template->name,
                'version' => $template->version,
                'photo_slots' => $template->photo_slots,
                'is_premium' => $template->is_premium,
            ]),
        ]);
    }

    public function show(Request $request): JsonResponse
    {
        return $this->forCouple($request, fn ($couple) => ApiResponse::success(
            'Couple theme retrieved successfully.',
            ['theme' => $this->themes->current($couple)],
        ));
    }

    public function update(UpdateCoupleThemeRequest $request): JsonResponse
    {
        return $this->forCouple($request, fn ($couple) => ApiResponse::success(
            'Couple theme updated successfully.',
            ['theme' => $this->themes->update(
                $couple,
                $request->user(),
                $request->validated('theme_key'),
                $request->validated('customization'),
                (int) $request->validated('version'),
            )],
        ));
    }

    public function resetCustomization(ResetCoupleThemeCustomizationRequest $request): JsonResponse
    {
        return $this->forCouple($request, fn ($couple) => ApiResponse::success(
            'Theme customization reset successfully.',
            ['theme' => $this->themes->resetCustomization($couple, $request->user(), (int) $request->validated('version'))],
        ));
    }

    /** Couple membership is the authorization: users only ever reach their own couple's settings. */
    private function forCouple(Request $request, callable $action): JsonResponse
    {
        try {
            $couple = $this->memoryService->getUserCouple($request->user());
        } catch (RuntimeException $exception) {
            return ApiResponse::error($exception->getMessage(), status: 404);
        }

        try {
            return $action($couple);
        } catch (ThemeVersionConflict $conflict) {
            return ApiResponse::error($conflict->getMessage(), ['theme' => $conflict->current], 409);
        }
    }
}
