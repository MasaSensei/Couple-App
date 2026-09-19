import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.primary,
      ),
    );
  }
}
