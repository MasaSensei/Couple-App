import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_definition.dart';
import 'package:frontend/core/theme/theme_registry.dart';

import '../providers/appearance_controller.dart';
import 'theme_preview.dart';

/// Preview + customization for one theme. Every control here changes only
/// the local preview; the shared theme changes after "Apply" is confirmed
/// and the server accepts it.
class ThemeDetailScreen extends ConsumerStatefulWidget {
  const ThemeDetailScreen({super.key, required this.definition});

  final ThemeDefinition definition;

  @override
  ConsumerState<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends ConsumerState<ThemeDetailScreen> {
  late ThemeCustomization _draft;

  bool get _isActive => ref.read(appearanceControllerProvider).settings.themeKey == widget.definition.key;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appearanceControllerProvider).settings;
    // Start from what the couple has if this is their theme, else the theme's defaults.
    _draft = settings.themeKey == widget.definition.key ? settings.customization : ThemeCustomization.defaults;
  }

  Future<void> _apply() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use ${widget.definition.name}?'),
        content: const Text('Your partner will see this theme too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await ref.read(appearanceControllerProvider.notifier).apply(widget.definition.key, _draft);
    if (!mounted) return;

    final current = ref.read(appearanceControllerProvider).settings;
    final message = switch (outcome) {
      ApplyOutcome.applied => '${widget.definition.name} is now your theme ♡',
      ApplyOutcome.conflict =>
        'Your partner just changed the theme to ${ThemeRegistry.byKey(current.themeKey).name}. Review it, then apply again if you like.',
      ApplyOutcome.failed => "We couldn't save the theme. Your current theme hasn't changed.",
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (outcome == ApplyOutcome.applied) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final outcome = await ref.read(appearanceControllerProvider.notifier).resetCustomization();
    if (!mounted) return;

    if (outcome == ApplyOutcome.applied) setState(() => _draft = ThemeCustomization.defaults);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (outcome) {
        ApplyOutcome.applied => 'Back to the ${widget.definition.name} defaults.',
        ApplyOutcome.conflict => 'Your partner changed the theme a moment ago. Have a look first.',
        ApplyOutcome.failed => "We couldn't reset it. Nothing changed.",
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appearanceControllerProvider);
    final def = widget.definition;
    final isActive = state.settings.themeKey == def.key;
    final unchanged = isActive && state.settings.customization == _draft;

    return Scaffold(
      appBar: AppBar(title: Text(def.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(def.tagline, style: context.tokens.subtitle),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: 'Preview of ${def.name}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.tokens.cardRadius),
                child: SizedBox(
                  height: 300,
                  child: ThemeScope(definition: def, customization: _draft, animate: true, child: const ThemePreview()),
                ),
              ),
            ),
            if (isActive && state.partnerChanged)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text('Updated by your partner.', style: context.tokens.subtitle),
              ),
            const SizedBox(height: AppSpacing.lg),
            if (def.accentPresets.isNotEmpty)
              _ChoiceRow(
                label: 'Accent',
                options: [for (final p in def.accentPresets) (p.key, p.label, p.primary)],
                selected: _draft.accent,
                onSelected: (key) => setState(() => _draft = _draft.copyWith(accent: () => key)),
              ),
            if (def.backgroundPresets.isNotEmpty)
              _ChoiceRow(
                label: 'Background',
                options: [for (final p in def.backgroundPresets) (p.key, p.label, p.background)],
                selected: _draft.background,
                onSelected: (key) => setState(() => _draft = _draft.copyWith(background: () => key)),
              ),
            if (def.fontPresets.isNotEmpty)
              _ChoiceRow(
                label: 'Font',
                options: [for (final p in def.fontPresets) (p.key, p.label, null)],
                selected: _draft.font,
                onSelected: (key) => setState(() => _draft = _draft.copyWith(font: () => key)),
              ),
            if (def.decoration.kind != DecorationKind.none)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Decorations'),
                value: _draft.decorations,
                onChanged: (value) => setState(() => _draft = _draft.copyWith(decorations: value)),
              ),
            if (def.animation.isAnimated)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Animations'),
                value: _draft.animations,
                onChanged: _draft.decorations ? (value) => setState(() => _draft = _draft.copyWith(animations: value)) : null,
              ),
            const SizedBox(height: AppSpacing.sm),
            _SegmentRow<CoupleSpaceStyle>(
              label: 'Couple Space',
              values: CoupleSpaceStyle.values,
              selected: _draft.coupleSpaceStyle,
              onSelected: (value) => setState(() => _draft = _draft.copyWith(coupleSpaceStyle: value)),
            ),
            _SegmentRow<MemoryStyle>(
              label: 'Memories',
              values: MemoryStyle.values,
              selected: _draft.memoryStyle,
              onSelected: (value) => setState(() => _draft = _draft.copyWith(memoryStyle: value)),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: state.saving || unchanged ? null : _apply,
              child: state.saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(unchanged ? 'This is your theme' : (isActive ? 'Save changes' : 'Apply theme')),
            ),
            if (isActive && !state.settings.customization.isDefault) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: state.saving ? null : _reset, child: const Text('Reset to theme defaults')),
            ],
            if (!_isActive && !_draft.isDefault)
              TextButton(
                onPressed: () => setState(() => _draft = ThemeCustomization.defaults),
                child: const Text('Clear my changes'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.options, required this.selected, required this.onSelected});

  final String label;
  final List<(String, String, Color?)> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tokens.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              ChoiceChip(label: const Text('Default'), selected: selected == null, onSelected: (_) => onSelected(null)),
              for (final (key, name, color) in options)
                ChoiceChip(
                  avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 8),
                  label: Text(name),
                  selected: selected == key,
                  onSelected: (_) => onSelected(key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentRow<T extends Enum> extends StatelessWidget {
  const _SegmentRow({required this.label, required this.values, required this.selected, required this.onSelected});

  final String label;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    String title(String name) => name[0].toUpperCase() + name.substring(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tokens.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<T>(
            segments: [for (final v in values) ButtonSegment(value: v, label: Text(title(v.name)))],
            selected: {selected},
            onSelectionChanged: (s) => onSelected(s.first),
          ),
        ],
      ),
    );
  }
}
