import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(symbol: '\$');

String money(num value) => _currency.format(value);
