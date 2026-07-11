import 'package:intl/intl.dart';

class CurrencyOption {
  final String code;
  final String symbol;
  final String label;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.label,
  });
}

const currencyOptions = [
  CurrencyOption(code: 'USD', symbol: r'$', label: 'USD - US Dollar'),
  CurrencyOption(code: 'PKR', symbol: 'Rs ', label: 'PKR - Pakistani Rupee'),
  CurrencyOption(code: 'EUR', symbol: 'EUR ', label: 'EUR - Euro'),
  CurrencyOption(code: 'GBP', symbol: 'GBP ', label: 'GBP - British Pound'),
  CurrencyOption(code: 'INR', symbol: 'INR ', label: 'INR - Indian Rupee'),
  CurrencyOption(code: 'AED', symbol: 'AED ', label: 'AED - UAE Dirham'),
  CurrencyOption(code: 'SAR', symbol: 'SAR ', label: 'SAR - Saudi Riyal'),
];

CurrencyOption currencyOptionForCode(String code) => currencyOptions.firstWhere(
      (option) => option.code == code,
      orElse: () => currencyOptions.first,
    );

String _currencySymbol = r'$';

void setMoneyCurrency(String symbol) {
  _currencySymbol = symbol;
}

String money(num value, {String? symbol}) =>
    NumberFormat.currency(symbol: symbol ?? _currencySymbol).format(value);
