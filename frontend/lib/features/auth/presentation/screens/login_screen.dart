import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '/core/theme/app_spacing.dart';
import '/core/theme/app_text_styles.dart';
import '/core/widgets/app_button.dart';
import '/core/widgets/app_text_field.dart';
import '../../providers/auth_providers.dart';
import '../../providers/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .login(email: email, password: password);

    if (!mounted) {
      return;
    }

    final state = ref.read(authNotifierProvider);

    if (state.status == AuthStatus.authenticated) {
      _showMessage('Welcome back, ${state.user!.name} ♡');
      return;
    }

    if (state.status == AuthStatus.error) {
      _showMessage(state.message ?? 'Login failed.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              Text('Welcome back ♡', style: AppTextStyles.display),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Sign in to your little space together.',
                style: AppTextStyles.subtitle,
              ),

              const SizedBox(height: AppSpacing.xxl),

              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.mail_outline_rounded,
              ),

              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
              ),

              const SizedBox(height: AppSpacing.xl),

              AppButton(
                label: 'Continue',
                isLoading: isLoading,
                onPressed: _handleLogin,
              ),

              const SizedBox(height: AppSpacing.lg),

              Center(
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          context.push('/register');
                        },
                  child: const Text('Create a new account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
