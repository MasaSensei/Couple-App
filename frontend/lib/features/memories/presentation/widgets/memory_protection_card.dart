import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/memory_protection_summary.dart';
import '../../providers/memory_providers.dart';

/// "Memory Protection ❤️": what the server has verified about the couple's
/// photos. Only says "protected" when every stored photo has a verified
/// primary and backup copy; never hides pending or problem photos.
class MemoryProtectionCard extends StatelessWidget {
  const MemoryProtectionCard({required this.summary, super.key});

  final MemoryProtectionSummary summary;

  static String headline(MemoryProtectionSummary summary) {
    return switch (summary.state) {
      'protected' => 'All your photos are safely backed up',
      'backing_up' => 'Some photos are still being backed up',
      'restoring' => 'We are repairing a stored copy',
      'needs_attention' => 'Some photos need attention',
      _ => 'No photos yet',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (summary.state) {
      'protected' => AppColors.success,
      'needs_attention' => AppColors.error,
      _ => AppColors.primary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Memory Protection ❤️', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              summary.isFullyProtected ? Icons.verified_user_outlined : Icons.shield_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(headline(summary), style: AppTextStyles.body.copyWith(color: color))),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _row('Photos', summary.photos),
        _row('Protected', summary.protected),
        if (summary.backingUp > 0) _row('Backing up', summary.backingUp),
        if (summary.uploading > 0) _row('Uploading', summary.uploading),
        if (summary.restoring > 0) _row('Restoring', summary.restoring),
        if (summary.needsAttention > 0) _row('Needs attention', summary.needsAttention),
        if (summary.uploadFailed > 0) _row('Upload failed', summary.uploadFailed),
        const SizedBox(height: AppSpacing.md),
        _when('Last integrity check', summary.lastIntegrityCheckAt),
        _when('Last verified backup', summary.lastVerifiedBackupAt),
        if (summary.needsAttention > 0 || summary.uploadFailed > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            summary.uploadFailed > 0
                ? 'A failed upload is still on your phone. Open the memory to try again.'
                : 'We keep two copies of every photo and are working on it. '
                    'Your photos stay encrypted the whole time.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text('$value', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _when(String label, DateTime? at) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: ${at == null ? 'not yet' : formatWhen(at.toLocal())}',
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  static String formatWhen(DateTime at, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;

    return switch (days) {
      0 => 'Today, $time',
      1 => 'Yesterday, $time',
      _ => '${at.day}/${at.month}/${at.year}, $time',
    };
  }
}

/// Bottom sheet that loads the summary from the server each time it opens.
Future<void> showMemoryProtectionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final summary = ref.watch(memoryProtectionProvider);

        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          child: summary.when(
            data: (data) => MemoryProtectionCard(summary: data),
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            // Never fall back to a reassuring default when the status is unknown.
            error: (_, _) => SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  "We couldn't check your photos' protection right now.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
