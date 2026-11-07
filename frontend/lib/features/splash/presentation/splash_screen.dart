import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';

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
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Center(child: _buildStatus(context)),
            ),
          ],
        ),
      ),
    );
  }

  /// Spinner while checking the session; message + retry when the server
  /// could not be reached (the saved session is kept).
  Widget _buildStatus(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);

    if (auth.status == AuthStatus.error) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            auth.message ?? 'Something went wrong.',
            style: context.tokens.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).checkAuth(),
            child: const Text('Try again'),
          ),
        ],
      );
    }

    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: context.tokens.primary,
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
        child: Icon(
          Icons.favorite_rounded,
          size: 52,
          color: context.tokens.primary,
        ),
      ),
    );
  }
}
