import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '/core/theme/app_spacing.dart';
import '/core/theme/app_text_styles.dart';
import '/core/widgets/app_button.dart';
import '/core/widgets/app_text_field.dart';
import '../../providers/auth_providers.dart';
import '../../providers/auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        passwordConfirmation.isEmpty) {
      _showMessage('Please complete all fields.');
      return;
    }

    if (password != passwordConfirmation) {
      _showMessage('Passwords do not match.');
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .register(
          name: name,
          email: email,
          password: password,
          passwordConfirmation: passwordConfirmation,
        );

    if (!mounted) {
      return;
    }

    final state = ref.read(authNotifierProvider);

    if (state.status == AuthStatus.authenticated) {
      _showMessage('Welcome, ${state.user!.name} ♡');
      return;
    }

    if (state.status == AuthStatus.error) {
      _showMessage(state.message ?? 'Registration failed.');
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create your space ♡', style: AppTextStyles.display),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'A little place made just for the two of you.',
                style: AppTextStyles.subtitle,
              ),

              const SizedBox(height: AppSpacing.xxl),

              AppTextField(
                controller: _nameController,
                label: 'Your name',
                hint: 'What should we call you?',
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: AppSpacing.md),

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
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.lock_outline_rounded,
              ),

              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _passwordConfirmationController,
                label: 'Confirm password',
                obscureText: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
              ),

              const SizedBox(height: AppSpacing.xl),

              AppButton(
                label: 'Create account',
                isLoading: isLoading,
                onPressed: _handleRegister,
              ),

              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          context.pop();
                        },
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
