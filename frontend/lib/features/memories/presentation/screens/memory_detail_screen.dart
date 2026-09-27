import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/memory_model.dart';

class MemoryDetailScreen extends ConsumerWidget {
  const MemoryDetailScreen({required this.memory, super.key});

  final MemoryModel memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDate(),
              const SizedBox(height: AppSpacing.md),

              Text(
                memory.title,
                style: AppTextStyles.display.copyWith(fontSize: 28),
              ),

              if (memory.locationName != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildLocation(),
              ],

              if (memory.description != null &&
                  memory.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  memory.description!,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              _buildSectionPlaceholder(
                icon: Icons.photo_library_outlined,
                title: 'Photos',
                subtitle: 'Your photos will appear here.',
              ),

              const SizedBox(height: AppSpacing.md),

              _buildSectionPlaceholder(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Comments',
                subtitle: 'Comments will appear here.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDate() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatDate(memory.memoryDate),
        style: AppTextStyles.body.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLocation() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            memory.locationName!,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
