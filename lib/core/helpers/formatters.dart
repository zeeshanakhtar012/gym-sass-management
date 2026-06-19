import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(symbol: 'PKR ', decimalDigits: 0);
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _monthYearFormat = DateFormat('MMM yyyy');
  static final _shortDateFormat = DateFormat('dd MMM yyyy');

  static String currency(int amount) => _currencyFormat.format(amount);

  static String date(DateTime? date) =>
      date != null ? _dateFormat.format(date) : '-';

  static String dateTime(DateTime? date) =>
      date != null ? _dateTimeFormat.format(date) : '-';

  static String time(DateTime? date) =>
      date != null ? _timeFormat.format(date) : '-';

  static String shortDate(DateTime? date) =>
      date != null ? _shortDateFormat.format(date) : '-';

  static String monthYear(DateTime? date) =>
      date != null ? _monthYearFormat.format(date) : '-';

  static String phone(String phone) {
    if (phone.length == 11) {
      return '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}';
    }
    return phone;
  }

  static String remainingDays(int days) {
    if (days < 0) return 'Expired';
    if (days == 0) return 'Last day';
    if (days == 1) return '1 day remaining';
    return '$days days remaining';
  }

  static String attendancePercent(int present, int total) {
    if (total == 0) return '0%';
    final pct = (present / total * 100).toStringAsFixed(1);
    return '$pct%';
  }
}
