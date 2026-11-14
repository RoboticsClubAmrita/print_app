import 'package:flutter_test/flutter_test.dart';

import 'package:print_service_app/data/pricing.dart';
import 'package:print_service_app/models/print_order.dart';

Map<String, dynamic> _row(String size, String type, String side, num price,
        {bool? isActive}) =>
    {
      'size': size,
      'type': type,
      'side': side,
      'price': price,
      if (isActive != null) 'isActive': isActive,
    };

/// The live tariff from the admin console (Pricing & Rules).
final _tariff = [
  _row('A4', 'bw', 'single', 2),
  _row('A4', 'bw', 'double', 3),
  _row('A4', 'colour', 'single', 10),
  _row('A4', 'colour', 'double', 18),
  _row('A3', 'bw', 'single', 4),
  _row('A3', 'bw', 'double', 7),
  _row('A3', 'colour', 'single', 20),
  _row('A3', 'colour', 'double', 36),
  _row('A2', 'bw', 'single', 8),
  _row('A2', 'bw', 'double', 15),
  _row('A2', 'colour', 'single', 40),
  _row('A2', 'colour', 'double', 72),
];

void main() {
  group('rateFor', () {
    test('picks the rate for the exact size × colour × side', () {
      expect(rateFor(_tariff, pageType: 'A4', colorMode: 'BW', side: PrintSide.single), 2);
      expect(rateFor(_tariff, pageType: 'A4', colorMode: 'COLOR', side: PrintSide.double), 18);
      expect(rateFor(_tariff, pageType: 'A3', colorMode: 'BW', side: PrintSide.double), 7);
      expect(rateFor(_tariff, pageType: 'A2', colorMode: 'COLOR', side: PrintSide.single), 40);
    });

    test('is null for an unpriced or inactive combination', () {
      expect(rateFor(const [], pageType: 'A4', colorMode: 'BW', side: PrintSide.single), isNull);
      expect(
        rateFor([_row('A2', 'bw', 'single', 8, isActive: false)],
            pageType: 'A2', colorMode: 'BW', side: PrintSide.single),
        isNull,
      );
    });
  });

  group('printCost', () {
    test('bills like the backend: copies × pages (or sheets when duplex) × rate', () {
      expect(printCost(pages: 8, copies: 2, side: PrintSide.single, rate: 2), 32);
      expect(printCost(pages: 5, copies: 1, side: PrintSide.double, rate: 3), 9);
      expect(printCost(pages: 5, copies: 2, side: PrintSide.double, rate: 36), 216);
      expect(printCost(pages: 0, copies: 3, side: PrintSide.single, rate: 2), 0);
      expect(printCost(pages: 3, copies: 0, side: PrintSide.double, rate: 3), 0);
    });
  });

  test('rateLabel says per page / per sheet', () {
    expect(rateLabel(2, PrintSide.single), '₹2 / page');
    expect(rateLabel(18, PrintSide.double), '₹18 / sheet');
  });
}
