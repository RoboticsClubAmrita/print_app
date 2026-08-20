import '../models/print_order.dart';

/// Print rates in rupees. Adjust here to change pricing app-wide.
const int singleSidedPerPage = 2;
const int doubleSidedPerSheet = 3;

/// Chargeable units for one copy: pages when single-sided, sheets when
/// double-sided (two pages share a sheet). Both the published rates here and
/// the backend's `print_prices` rows quote the double-sided price per SHEET,
/// so any rate must be multiplied by this — never by the raw page count.
int billableUnits(int pages, PrintSide side) =>
    side == PrintSide.single ? pages : (pages + 1) ~/ 2;

int printCost({
  required int pages,
  required int copies,
  required PrintSide side,
}) {
  if (pages <= 0 || copies <= 0) return 0;
  final rate = side == PrintSide.single ? singleSidedPerPage : doubleSidedPerSheet;
  return copies * billableUnits(pages, side) * rate;
}

String rateLabel(PrintSide side) => side == PrintSide.single
    ? '₹$singleSidedPerPage / page'
    : '₹$doubleSidedPerSheet / sheet';

/// Labels a rate the backend charged. Double-sided prices are per SHEET
/// (two pages share one), so calling every rate "per page" misreads the
/// duplex price by a factor of two.
String backendRateLabel(num rate, PrintSide side) =>
    side == PrintSide.single ? '₹$rate / page' : '₹$rate / sheet';

String rupees(int amount) => '₹$amount';
