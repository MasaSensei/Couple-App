import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';


class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: context.tokens.primary,
      ),
    );
  }
}
