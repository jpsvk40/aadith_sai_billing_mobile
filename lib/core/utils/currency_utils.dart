import 'package:intl/intl.dart';

class CurrencyUtils {
  static final _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _compactFormatter = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String format(dynamic amount) {
    if (amount == null) return '₹0.00';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return _inrFormatter.format(value);
  }

  static String formatCompact(dynamic amount) {
    if (amount == null) return '₹0';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return _compactFormatter.format(value);
  }

  static double parse(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[₹,\s]'), '')) ?? 0.0;
  }
}
