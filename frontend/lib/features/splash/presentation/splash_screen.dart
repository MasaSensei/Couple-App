import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_providers.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() => ref.read(authNotifierProvider.notifier).checkAuth());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeartLogo(),

                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'Our Little Space',
                      style: context.tokens.display,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      'A private place for the two of you.',
                      style: context.tokens.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: context.tokens.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartLogo() {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: context.tokens.secondary.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(Icons.favorite_rounded, size: 52, color: context.tokens.primary),
      ),
    );
  }
}
