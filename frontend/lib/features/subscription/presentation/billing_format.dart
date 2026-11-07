/// Plain formatting helpers: prices are shown in full, with the billing
/// interval, so nothing about the cost is ambiguous.
abstract final class BillingFormat {
  /// Currencies whose amounts have no minor unit (ISO 4217 exponent 0).
  static const _zeroDecimal = {'IDR', 'JPY', 'KRW', 'VND', 'CLP', 'ISK', 'UGX'};

  static String price(int amount, String currency) {
    final negative = amount < 0;
    final abs = amount.abs();
    final String number;

    if (_zeroDecimal.contains(currency)) {
      number = _group(abs.toString(), '.');
    } else {
      final major = abs ~/ 100;
      final minor = (abs % 100).toString().padLeft(2, '0');
      number = '${_group(major.toString(), ',')}.$minor';
    }

    final symbol = currency == 'IDR' ? 'Rp ' : '$currency ';
    return '${negative ? '−' : ''}$symbol$number';
  }

  static String interval(String interval, int count) {
    if (interval == 'none') return '';
    final unit = interval == 'year' ? 'year' : 'month';
    return count == 1 ? 'per $unit' : 'every $count ${unit}s';
  }

  static String priceWithInterval(int amount, String currency, String interval, int count) {
    if (interval == 'none' && amount == 0) return 'Free';
    final suffix = BillingFormat.interval(interval, count);
    return suffix.isEmpty ? price(amount, currency) : '${price(amount, currency)} $suffix';
  }

  static String bytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = value >= 100 || unit == 0 ? value.round().toString() : value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '$text ${units[unit]}';
  }

  static String date(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Human, non-alarming status text.
  static String status(String status) => switch (status) {
        'active' => 'Active',
        'cancelled' => 'Cancelled — benefits until the period ends',
        'grace_period' => 'Payment problem — benefits continue for now',
        'payment_failed' => 'Payment failed',
        'suspended' => 'Paused',
        'pending' => 'Waiting for payment',
        'expired' => 'Ended',
        _ => status,
      };

  static String _group(String digits, String separator) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
