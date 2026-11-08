import 'package:flutter/material.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/date_model.dart';

/// Presentation of the backend date statuses (`planned`, `completed`,
/// `cancelled`). Unknown statuses from a newer server show neutrally.
abstract final class DateStatusStyle {
  static (String, StatusTone, IconData) of(String status) => switch (status) {
    'planned' => ('Planned', StatusTone.brand, Icons.event_available_rounded),
    'completed' => ('Completed', StatusTone.success, Icons.check_rounded),
    'cancelled' => ('Cancelled', StatusTone.neutral, Icons.event_busy_rounded),
    _ => (
      status.isEmpty
          ? 'Unknown'
          : status[0].toUpperCase() + status.substring(1),
      StatusTone.neutral,
      Icons.help_outline_rounded,
    ),
  };

  static bool isUpcoming(DateModel date, {DateTime? now}) =>
      date.status == 'planned' &&
      AppFormatters.daysBetween(now ?? DateTime.now(), date.scheduledAt) >= 0;
}

class DateStatusChip extends StatelessWidget {
  const DateStatusChip({required this.status, super.key, this.dense = true});

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = DateStatusStyle.of(status);
    return StatusChip(label: label, tone: tone, icon: icon, dense: dense);
  }
}
