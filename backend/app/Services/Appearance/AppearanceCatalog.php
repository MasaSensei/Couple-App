<?php

namespace App\Services\Appearance;

use App\Models\PhotoBoothTemplate;
use App\Models\Theme;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The theme / Photo Booth catalog, seeded from database/data/appearance_catalog.json
 * (the keys the Flutter app knows how to draw).
 *
 * sync() is safe to re-run on every release: it adds new items and updates
 * names, versions and allowed options, but never touches what admins manage
 * (status, premium flag, order of existing items) and never deletes rows, so
 * couples using an item that was hidden or retired keep their setting.
 */
class AppearanceCatalog
{
    public function data(): array
    {
        return json_decode(file_get_contents(database_path('data/appearance_catalog.json')), true, flags: JSON_THROW_ON_ERROR);
    }

    public function sync(): array
    {
        $data = $this->data();
        $counts = ['themes' => 0, 'templates' => 0];

        DB::transaction(function () use ($data, &$counts): void {
            foreach ($data['themes'] as $item) {
                $theme = Theme::firstOrNew(['key' => $item['key']]);
                $isNew = ! $theme->exists;
                $theme->forceFill([
                    'key' => $item['key'],
                    'name' => $isNew ? $item['name'] : $theme->name,
                    'version' => $item['version'],
                    'is_default' => $item['is_default'],
                    'options' => $item['options'],
                    ...($isNew ? ['sort_order' => $item['sort_order'], 'status' => 'active'] : []),
                ])->save();
                $counts['themes']++;
            }

            foreach ($data['photo_booth_templates'] as $item) {
                $template = PhotoBoothTemplate::firstOrNew(['key' => $item['key']]);
                $isNew = ! $template->exists;
                $template->forceFill([
                    'key' => $item['key'],
                    'name' => $isNew ? $item['name'] : $template->name,
                    'version' => $item['version'],
                    'photo_slots' => $item['photo_slots'],
                    ...($isNew ? ['sort_order' => $item['sort_order'], 'status' => 'active'] : []),
                ])->save();
                $counts['templates']++;
            }
        });

        return $counts;
    }

    /**
     * Validates a couple's customization against the theme's presets. Only
     * known keys with allowed values are accepted: no free-form colours or
     * fonts, so the UI can never end up unreadable. Returns the normalised
     * value (defaults omitted).
     *
     * @throws ValidationException
     */
    public function validateCustomization(Theme $theme, array $customization): array
    {
        $allowed = [
            'accent' => $theme->options['accents'] ?? [],
            'background' => $theme->options['backgrounds'] ?? [],
            'font' => $theme->options['fonts'] ?? [],
            'couple_space_style' => $this->data()['customization']['couple_space_styles'],
            'memory_style' => $this->data()['customization']['memory_styles'],
        ];
        $errors = [];
        $clean = [];

        foreach ($customization as $key => $value) {
            if (in_array($key, ['decorations', 'animations'], true)) {
                is_bool($value) ? $clean[$key] = $value : $errors["customization.{$key}"] = 'Must be true or false.';

                continue;
            }

            if (! array_key_exists($key, $allowed)) {
                $errors["customization.{$key}"] = 'This option is not supported.';

                continue;
            }

            if (! is_string($value) || ! in_array($value, $allowed[$key], true)) {
                $errors["customization.{$key}"] = "Not an available {$key} for this theme.";

                continue;
            }

            $clean[$key] = $value;
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        // Defaults are implicit; storing them would make "reset" ambiguous.
        return array_filter($clean, fn ($value, $key) => ! (
            ($key === 'decorations' || $key === 'animations') && $value === true
            || $key === 'couple_space_style' && $value === 'classic'
            || $key === 'memory_style' && $value === 'soft'
        ), ARRAY_FILTER_USE_BOTH);
    }
}
