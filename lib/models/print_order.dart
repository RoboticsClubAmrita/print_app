import '../data/pricing.dart';

enum OrderStatus { queued, printing, ready, collected }

enum PrintSide { single, double }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.queued => 'Queued',
        OrderStatus.printing => 'Printing',
        OrderStatus.ready => 'Ready to Collect',
        OrderStatus.collected => 'Collected',
      };
}

extension PrintSideLabel on PrintSide {
  String get label =>
      this == PrintSide.single ? 'Single-sided' : 'Double-sided';
}

class PrintOrder {
  final String id;
  final String fileName;
  final int fileSizeKb;
  final int pages;
  final int copies;
  final PrintSide side;
  final DateTime createdAt;
  final DateTime scheduledAt;
  final bool scheduledNow;
  OrderStatus status;
  bool paid;

  PrintOrder({
    required this.id,
    required this.fileName,
    required this.fileSizeKb,
    required this.pages,
    required this.copies,
    required this.side,
    required this.createdAt,
    required this.scheduledAt,
    required this.scheduledNow,
    this.status = OrderStatus.queued,
    this.paid = false,
  });

  int get cost => printCost(pages: pages, copies: copies, side: side);

  /// Sheets of paper used per copy (double-sided fits 2 pages per sheet).
  int get sheetsPerCopy => side == PrintSide.single ? pages : (pages + 1) ~/ 2;
}
