import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_decorations.dart';

/// Scaffold with the app's page rules: theme background ornaments (optional),
/// a readable max content width on tablets, and the standard gutter.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    super.key,
    this.title,
    this.actions,
    this.appBar,
    this.floatingActionButton,
    this.decorated = false,
    this.padded = true,
    this.bottomNavigationBar,
  });

  final String? title;
  final List<Widget>? actions;

  /// Custom app bar; overrides [title]/[actions]. Pass none for no app bar.
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// Paint the theme's background ornaments (journal screens only).
  final bool decorated;

  /// Apply the horizontal gutter. Lists that pad themselves pass false.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: padded
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: body,
              )
            : body,
      ),
    );

    if (decorated) content = ThemedBackground(child: content);

    return Scaffold(
      appBar:
          appBar ??
          (title == null
              ? null
              : AppBar(title: Text(title!), actions: actions)),
      body: content,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
