import '../models/print_order.dart';

/// Print rates in rupees. Adjust here to change pricing app-wide.
const int singleSidedPerPage = 2;
const int doubleSidedPerSheet = 3;

int printCost({
  required int pages,
  required int copies,
  required PrintSide side,
}) {
  if (pages <= 0 || copies <= 0) return 0;
  final perCopy = side == PrintSide.single
      ? pages * singleSidedPerPage
      : ((pages + 1) ~/ 2) * doubleSidedPerSheet;
  return copies * perCopy;
}

String rateLabel(PrintSide side) => side == PrintSide.single
    ? '₹$singleSidedPerPage / page'
    : '₹$doubleSidedPerSheet / sheet';

String rupees(int amount) => '₹$amount';
