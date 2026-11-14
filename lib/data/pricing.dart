import '../models/print_order.dart';

/// Print pricing. Every rate comes from the backend's live tariff
/// (`GET /pricing/all`, edited in the admin console's Pricing & Rules, and
/// held in `AppState.pricing`) — there is no local price table, so what the
/// order screen shows is what the backend will charge.

/// Paper sizes, in the order the order form offers them.
const paperSizes = ['A4', 'A3', 'A2'];

/// Chargeable units for one copy: pages when single-sided, sheets when
/// double-sided (two pages share a sheet). The backend's `print_prices` rows
/// quote the double-sided price per SHEET, so any rate must be multiplied by
/// this — never by the raw page count. Mirrors the backend's `billableUnits`.
int billableUnits(int pages, PrintSide side) =>
    side == PrintSide.single ? pages : (pages + 1) ~/ 2;

/// The tariff rate (₹ per page single-sided, ₹ per sheet double-sided) for
/// an order's choices, or null when the admin has not priced (or has
/// deactivated) that combination — the backend refuses such an order.
///
/// [colorMode] is the job's `BW` / `COLOR`; [pageType] is `A4` / `A3` / `A2`.
num? rateFor(
  List<Map<String, dynamic>> pricing, {
  required String pageType,
  required String colorMode,
  required PrintSide side,
}) {
  final type = colorMode == 'COLOR' ? 'colour' : 'bw';
  final tariffSide = side == PrintSide.double ? 'double' : 'single';
  for (final row in pricing) {
    final active = row['isActive'] ?? row['is_active'] ?? true;
    if (active == false) continue;
    if (row['size'] == pageType && row['type'] == type && row['side'] == tariffSide) {
      final price = row['price'];
      return price is num ? price : num.tryParse('$price');
    }
  }
  return null;
}

/// copies × billable units × rate, in whole rupees like the rest of the app.
int printCost({
  required int pages,
  required int copies,
  required PrintSide side,
  required num rate,
}) {
  if (pages <= 0 || copies <= 0 || rate <= 0) return 0;
  return (copies * billableUnits(pages, side) * rate).round();
}

/// Double-sided prices are per SHEET (two pages share one), so say so.
String rateLabel(num rate, PrintSide side) =>
    side == PrintSide.single ? '₹$rate / page' : '₹$rate / sheet';

String rupees(int amount) => '₹$amount';
