import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_spacing.dart';

import '../data/subscription_models.dart';
import 'billing_format.dart';

class StorageUsageBar extends StatelessWidget {
  const StorageUsageBar({super.key, required this.storage});

  final StorageUsage storage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = storage.isFull ? scheme.error : (storage.fraction > 0.85 ? Colors.orange : scheme.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Storage used: ${(storage.fraction * 100).round()} percent',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: storage.fraction, minHeight: 10, color: color, backgroundColor: scheme.surfaceContainerHighest),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${BillingFormat.bytes(storage.usedBytes)} of ${BillingFormat.bytes(storage.limitBytes)} used',
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          storage.isFull ? 'Storage is full' : '${BillingFormat.bytes(storage.remainingBytes)} left',
          style: text.bodySmall?.copyWith(color: storage.isFull ? scheme.error : null),
        ),
      ],
    );
  }
}

class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.feature});

  final PlanFeature feature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = feature.type == 'bytes'
        ? '${BillingFormat.bytes((feature.value as num?)?.toInt() ?? 0)} ${feature.name.toLowerCase()}'
        : feature.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            feature.included ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            size: 18,
            color: feature.included ? scheme.primary : scheme.outline,
            semanticLabel: feature.included ? 'Included' : 'Not included',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: feature.included ? null : scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Always-visible list of what every plan keeps, so nobody thinks privacy is paid.
class AlwaysIncludedNote extends StatelessWidget {
  const AlwaysIncludedNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Every plan, including Free: end-to-end encrypted photos, private couple space, '
      'full access to your memories, and your data stays yours. If a paid plan ends, '
      'nothing is deleted — you just can’t add photos beyond the Free storage.',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
