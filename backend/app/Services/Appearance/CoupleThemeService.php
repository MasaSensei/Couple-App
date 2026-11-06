<?php

namespace App\Services\Appearance;

use App\Models\Couple;
use App\Models\CoupleThemeSetting;
use App\Models\Theme;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The couple's shared theme. Both partners see the same settings.
 *
 * Conflict rule: every write carries the `version` the client last saw.
 * The write succeeds only if that is still the current version (one
 * conditional UPDATE, so PostgreSQL serialises concurrent writers). A stale
 * write is rejected with ThemeVersionConflict carrying the current settings;
 * the app then shows what the partner chose and lets the user decide again.
 * Nothing is ever silently overwritten.
 */
class CoupleThemeService
{
    public function __construct(
        private readonly AppearanceCatalog $catalog,
    ) {}

    public function current(Couple $couple): array
    {
        $setting = CoupleThemeSetting::where('couple_id', $couple->id)->first();

        if ($setting === null) {
            $default = Theme::default();

            return [
                'theme_key' => $default->key,
                'theme_version' => $default->version,
                'customization' => (object) [],
                'version' => 0,
                'updated_by' => null,
                'updated_at' => null,
            ];
        }

        return $this->present($setting);
    }

    /**
     * @throws ValidationException|ThemeVersionConflict
     */
    public function update(Couple $couple, User $user, string $themeKey, array $customization, int $expectedVersion): array
    {
        $current = $this->current($couple);
        $theme = Theme::where('key', $themeKey)->first();

        // A hidden/retired theme may be kept (e.g. to tweak its customization) but not newly chosen.
        if ($theme === null || ($theme->status !== 'active' && $themeKey !== $current['theme_key'])) {
            throw ValidationException::withMessages(['theme_key' => 'This theme is not available.']);
        }

        return $this->write($couple, $user, $theme, $this->catalog->validateCustomization($theme, $customization), $expectedVersion);
    }

    /** Back to the theme's own defaults; the theme itself stays. */
    public function resetCustomization(Couple $couple, User $user, int $expectedVersion): array
    {
        $current = $this->current($couple);
        $theme = Theme::where('key', $current['theme_key'])->firstOrFail();

        return $this->write($couple, $user, $theme, [], $expectedVersion);
    }

    private function write(Couple $couple, User $user, Theme $theme, array $customization, int $expectedVersion): array
    {
        $values = [
            'theme_key' => $theme->key,
            'theme_version' => $theme->version,
            'customization' => json_encode((object) $customization),
            'updated_by' => $user->id,
            'updated_at' => now(),
        ];

        if ($expectedVersion === 0) {
            try {
                // Own savepoint: a failed insert must not poison an outer transaction.
                DB::transaction(fn () => CoupleThemeSetting::query()->insert([
                    ...$values,
                    'couple_id' => $couple->id,
                    'version' => 1,
                    'created_at' => now(),
                ]));
            } catch (UniqueConstraintViolationException) {
                // The partner created the row first.
                throw new ThemeVersionConflict($this->current($couple));
            }
        } else {
            $updated = CoupleThemeSetting::query()
                ->where('couple_id', $couple->id)
                ->where('version', $expectedVersion)
                ->update([...$values, 'version' => $expectedVersion + 1]);

            if ($updated === 0) {
                throw new ThemeVersionConflict($this->current($couple));
            }
        }

        return $this->current($couple);
    }

    private function present(CoupleThemeSetting $setting): array
    {
        return [
            'theme_key' => $setting->theme_key,
            'theme_version' => $setting->theme_version,
            'customization' => (object) ($setting->customization ?? []),
            'version' => $setting->version,
            'updated_by' => $setting->updated_by,
            'updated_at' => $setting->updated_at?->toISOString(),
        ];
    }
}
