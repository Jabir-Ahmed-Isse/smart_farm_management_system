import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00');
final _moneyCompact = NumberFormat('#,##0');

/// "$1,234.56" — the app's money format. Currency symbol kept simple for now;
/// a proper currency setting arrives with localization (Phase G).
String formatMoney(num value) => '\$${_money.format(value)}';

/// "$1,235" — no decimals, for tighter spots.
String formatMoneyCompact(num value) => '\$${_moneyCompact.format(value)}';

/// Rough growth fraction (0–1) for a crop stage, used for progress bars.
double cropStageProgress(String stage) {
  switch (stage) {
    case 'seed':
      return 0.05;
    case 'germination':
      return 0.2;
    case 'vegetative':
      return 0.4;
    case 'flowering':
      return 0.6;
    case 'fruiting':
      return 0.8;
    case 'harvest':
      return 0.95;
    case 'completed':
      return 1.0;
    default:
      return 0.0;
  }
}
