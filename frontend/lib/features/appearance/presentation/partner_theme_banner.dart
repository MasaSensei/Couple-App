import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_registry.dart';

import '../providers/appearance_controller.dart';
import 'theme_gallery_screen.dart';

/// Tells the user their partner changed the shared theme, so a new look
/// never appears without explanation.
class PartnerThemeBanner extends ConsumerWidget {
  const PartnerThemeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appearanceControllerProvider);
    if (!state.partnerChanged) return const SizedBox.shrink();

    final t = context.tokens;

    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.palette_outlined, color: t.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Your partner changed your theme to ${ThemeRegistry.byKey(state.settings.themeKey).name}.',
                  style: t.body,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(appearanceControllerProvider.notifier)
                      .acknowledgePartnerChange();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ThemeGalleryScreen(),
                    ),
                  );
                },
                child: const Text('See'),
              ),
              IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => ref
                    .read(appearanceControllerProvider.notifier)
                    .acknowledgePartnerChange(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
