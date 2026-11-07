import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/memory_model.dart';

import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';

class MemoryCard extends StatelessWidget {
  const MemoryCard({required this.memory, this.onTap, super.key});

  final MemoryModel memory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The couple's Memory style: soft rounded cards, polaroid prints, or flat minimal rows.
    final radius = switch (t.memoryStyle) {
      MemoryStyle.soft => t.cardRadius,
      MemoryStyle.polaroid => 4.0,
      MemoryStyle.minimal => 0.0,
    };

    return Card(
      elevation: t.memoryStyle == MemoryStyle.polaroid ? 3 : t.cardElevation,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: t.memoryStyle == MemoryStyle.minimal || !t.cardBorder
            ? BorderSide.none
            : BorderSide(color: t.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDate(context),

              const SizedBox(height: AppSpacing.sm),

              Text(
                memory.title,
                style: context.tokens.title.copyWith(fontSize: 20),
              ),

              if (memory.locationName != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: context.tokens.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        memory.locationName!,
                        style: context.tokens.body.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (memory.description != null &&
                  memory.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  memory.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.tokens.body.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDate(BuildContext context) {
    final date = memory.memoryDate;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: context.tokens.secondary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            _formatDate(date),
            style: context.tokens.body.copyWith(
              color: context.tokens.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}
