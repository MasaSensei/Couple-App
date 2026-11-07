import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_definition.dart';
import 'package:frontend/core/theme/theme_registry.dart';

import '../providers/appearance_controller.dart';
import 'theme_detail_screen.dart';
import 'theme_preview.dart';

/// Lists the themes the server currently offers and the app can draw. Tapping
/// one opens a preview; nothing changes until the user confirms there.
class ThemeGalleryScreen extends ConsumerStatefulWidget {
  const ThemeGalleryScreen({super.key});

  @override
  ConsumerState<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends ConsumerState<ThemeGalleryScreen> {
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = await ref.read(appearanceControllerProvider.notifier).refresh();
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appearanceControllerProvider);
    final catalog = state.catalog;

    return Scaffold(
      appBar: AppBar(title: const Text('Themes')),
      body: SafeArea(
        child: switch ((catalog, _loading, _failed)) {
          (null, true, _) => const Center(child: CircularProgressIndicator()),
          (null, _, true) => _Message(
              icon: Icons.cloud_off_rounded,
              title: "We couldn't load the themes",
              body: 'Your current theme is unchanged. Check your connection and try again.',
              action: FilledButton(onPressed: _refresh, child: const Text('Try again')),
            ),
          _ => _buildGallery(context, state),
        },
      ),
    );
  }

  Widget _buildGallery(BuildContext context, AppearanceState state) {
    // Offered = in the server catalog AND drawable by this app version. The
    // active theme always shows, even if it was hidden after the couple chose it.
    final offered = state.catalog == null
        ? ThemeRegistry.all
        : ThemeRegistry.all
            .where((t) => state.catalog!.themes.any((c) => c.key == t.key) || t.key == state.settings.themeKey)
            .toList();
    final extra = offered.where((t) => t.key != ThemeRegistry.defaultKey).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Choose a look for your space. Your partner sees the same theme.',
                style: context.tokens.subtitle,
              ),
            ),
          ),
          if (_failed)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('Offline: showing the themes we know about.'),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.66,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final theme = offered[index];
                  return _ThemeCard(
                    definition: theme,
                    active: theme.key == state.settings.themeKey,
                    locked: state.catalog?.themes.any((c) => c.key == theme.key && c.locked) ?? false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ThemeDetailScreen(definition: theme)),
                    ),
                  );
                },
                childCount: offered.length,
              ),
            ),
          ),
          if (extra.isEmpty)
            const SliverToBoxAdapter(
              child: _Message(
                icon: Icons.palette_outlined,
                title: 'No extra themes yet',
                body: 'New themes will appear here when they are available.',
              ),
            ),
          const SliverToBoxAdapter(child: _PersonalPreferences()),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.definition, required this.active, required this.onTap, this.locked = false});

  final ThemeDefinition definition;
  final bool active;

  /// Premium theme not in the couple's plan: can be previewed, not applied.
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      selected: active,
      label: '${definition.name} theme${active ? ', active' : ''}${locked ? ', paid plan' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: active ? t.primary : t.border, width: active ? 2.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: ThemeScope(definition: definition, child: const ThemePreview(compact: true)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(definition.name, style: t.body.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (active) Icon(Icons.check_circle_rounded, color: t.primary, size: 20, semanticLabel: 'Active'),
                    if (locked && !active) Icon(Icons.lock_outline_rounded, color: t.primary, size: 18, semanticLabel: 'Paid plan'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Device-only settings, clearly separated from the shared couple theme.
class _PersonalPreferences extends ConsumerWidget {
  const _PersonalPreferences();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appearanceControllerProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Only on this device', style: context.tokens.title.copyWith(fontSize: 18)),
          const SizedBox(height: AppSpacing.xs),
          Text('These do not change what your partner sees.', style: context.tokens.subtitle),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {state.themeMode},
            onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text('Keep theme decorations still'),
            value: state.reduceMotion,
            onChanged: controller.setReduceMotion,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.tokens.primary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: context.tokens.title.copyWith(fontSize: 20), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: context.tokens.subtitle, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
        ],
      ),
    );
  }
}
