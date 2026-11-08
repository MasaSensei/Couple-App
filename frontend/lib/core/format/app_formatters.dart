/// Date and number formatting in one place (English UI, no `intl` needed).
/// All inputs are converted to local time first.
abstract final class AppFormatters {
  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String monthShort(DateTime d) => _monthsShort[d.toLocal().month - 1];
  static String monthLong(DateTime d) => _monthsLong[d.toLocal().month - 1];
  static String weekdayShort(DateTime d) =>
      _weekdaysShort[d.toLocal().weekday - 1];

  /// 6 Nov 2026
  static String dayMonthYear(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_monthsShort[l.month - 1]} ${l.year}';
  }

  /// November 2026
  static String monthYear(DateTime d) {
    final l = d.toLocal();
    return '${_monthsLong[l.month - 1]} ${l.year}';
  }

  /// 19:00
  static String time(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  /// Fri 19:00
  static String weekdayTime(DateTime d) => '${weekdayShort(d)} ${time(d)}';

  /// Fri, 14 Nov 2026 · 19:00
  static String full(DateTime d) =>
      '${weekdayShort(d)}, ${dayMonthYear(d)} · ${time(d)}';

  /// Calendar-day distance: "Today", "Tomorrow", "in 3 days", "Yesterday",
  /// "3 days ago". [now] is injectable for tests.
  static String relativeDays(DateTime d, {DateTime? now}) {
    final days = daysBetween(now ?? DateTime.now(), d);
    return switch (days) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      > 1 => 'in $days days',
      _ => '${-days} days ago',
    };
  }

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) {
    final a = from.toLocal();
    final b = to.toLocal();
    return DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  /// "2 h ago", "5 min ago", "Yesterday", "6 Nov" for activity feeds.
  static String sinceShort(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = n.difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24 && daysBetween(d, n) == 0) {
      return '${diff.inHours} h ago';
    }
    if (daysBetween(d, n) == 1) return 'Yesterday';
    final l = d.toLocal();
    return l.year == n.toLocal().year
        ? '${l.day} ${_monthsShort[l.month - 1]}'
        : dayMonthYear(d);
  }
}
