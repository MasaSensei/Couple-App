import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_tokens.dart';
import 'app_button.dart';
import 'spot_illustration.dart';

/// One look for loading, empty, error and offline states across the app.
///
/// [scrollable] wraps the view so it still works inside a `RefreshIndicator`.
class AppStateView extends StatelessWidget {
  const AppStateView._({
    required this.kind,
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.illustration,
    this.scrollable = false,
  });

  /// Centered spinner with an optional line of text.
  const AppStateView.loading({Key? key, String? message})
    : this._(kind: AppStateKind.loading, key: key, message: message);

  /// Nothing here yet: illustration, one sentence, at most one action.
  const AppStateView.empty({
    Key? key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    SpotKind illustration = SpotKind.heart,
    bool scrollable = false,
  }) : this._(
         kind: AppStateKind.empty,
         key: key,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
         illustration: illustration,
         scrollable: scrollable,
       );

  /// Something failed: what happened and a retry.
  const AppStateView.error({
    Key? key,
    String title = 'Something went wrong',
    String? message,
    String actionLabel = 'Try again',
    VoidCallback? onAction,
    bool scrollable = false,
  }) : this._(
         kind: AppStateKind.error,
         key: key,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
         illustration: SpotKind.cloudOff,
         scrollable: scrollable,
       );

  /// No connection: saved content may still show elsewhere.
  const AppStateView.offline({
    Key? key,
    String? message,
    VoidCallback? onAction,
    bool scrollable = false,
  }) : this._(
         kind: AppStateKind.error,
         key: key,
         title: "You're offline",
         message: message ?? 'Check your connection and try again.',
         actionLabel: 'Try again',
         onAction: onAction,
         illustration: SpotKind.cloudOff,
         scrollable: scrollable,
       );

  final AppStateKind kind;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final SpotKind? illustration;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final content = switch (kind) {
      AppStateKind.loading => Semantics(
        liveRegion: true,
        label: message ?? 'Loading',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message!, style: t.caption, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustration != null) SpotIllustration(kind: illustration!),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            liveRegion: kind == AppStateKind.error,
            child: Text(
              title!,
              style: t.title.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message!,
                style: t.body.copyWith(color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
              variant: kind == AppStateKind.error
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
            ),
          ],
        ],
      ),
    };

    final padded = Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: content,
    );

    // Always overflow-safe: in a short box (landscape, large text) the view
    // scrolls instead of clipping. [scrollable] also enables pull-to-refresh.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return Center(child: padded);
        return SingleChildScrollView(
          physics: scrollable
              ? const AlwaysScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: padded),
          ),
        );
      },
    );
  }
}

enum AppStateKind { loading, empty, error }

/// Shimmer-free placeholder block (a soft pulse; static with reduce motion).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius});

  final double? width;
  final double height;
  final double? radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.55).animate(_controller),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: t.surfaceMuted,
            borderRadius: BorderRadius.circular(
              widget.radius ?? t.cardRadius / 2,
            ),
          ),
        ),
      ),
    );
  }
}
