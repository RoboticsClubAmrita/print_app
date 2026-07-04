import '../data/pricing.dart';

enum OrderStatus { pending, queued, printing, ready, collected, cancelled, failed }

enum PrintSide { single, double }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Awaiting Payment',
        OrderStatus.queued => 'Queued',
        OrderStatus.printing => 'Printing',
        OrderStatus.ready => 'Ready to Collect',
        OrderStatus.collected => 'Collected',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.failed => 'Failed',
      };

  /// Maps the backend `Job.status` string to the app's [OrderStatus].
  static OrderStatus fromBackend(String? status) => switch (status) {
        'PENDING' => OrderStatus.pending,
        'QUEUED' => OrderStatus.queued,
        'PRINTING' => OrderStatus.printing,
        'COMPLETED' || 'PRINTED_PENDING_STACK' => OrderStatus.ready,
        'COLLECTED' => OrderStatus.collected,
        'CANCELLED' => OrderStatus.cancelled,
        'FAILED' => OrderStatus.failed,
        _ => OrderStatus.pending,
      };
}

extension PrintSideLabel on PrintSide {
  String get label =>
      this == PrintSide.single ? 'Single-sided' : 'Double-sided';

  /// Maps to the backend's `printSide` enum value.
  String get backendValue => this == PrintSide.single ? 'SINGLE' : 'DOUBLE';

  static PrintSide fromBackend(String? value) =>
      value == 'DOUBLE' ? PrintSide.double : PrintSide.single;
}

class PrintOrder {
  /// Human-friendly reference id shown in the UI (backend `referenceId`).
  final String id;

  /// Mongo `_id` of the job — required for cancel/collect/payment API calls.
  final String jobId;
  final String fileName;
  final int fileSizeKb;
  final int pages;
  final int copies;
  final PrintSide side;
  final DateTime createdAt;
  final DateTime scheduledAt;
  final bool scheduledNow;
  final num backendCost;
  OrderStatus status;

  PrintOrder({
    required this.id,
    this.jobId = '',
    required this.fileName,
    required this.fileSizeKb,
    required this.pages,
    required this.copies,
    required this.side,
    required this.createdAt,
    required this.scheduledAt,
    required this.scheduledNow,
    this.status = OrderStatus.queued,
    this.backendCost = 0,
  });

  factory PrintOrder.fromJob(Map<String, dynamic> job) {
    final createdAt =
        DateTime.tryParse(job['createdAt']?.toString() ?? '') ?? DateTime.now();
    return PrintOrder(
      id: (job['referenceId'] ?? job['_id'] ?? '').toString(),
      jobId: (job['_id'] ?? '').toString(),
      fileName: (job['originalName'] ?? 'Document').toString(),
      fileSizeKb: 0,
      pages: (job['totalPagesToPrint'] as num?)?.toInt() ?? 0,
      copies: (job['copies'] as num?)?.toInt() ?? 1,
      side: PrintSideLabel.fromBackend(job['printSide']?.toString()),
      createdAt: createdAt,
      scheduledAt: createdAt,
      scheduledNow: true,
      status: OrderStatusLabel.fromBackend(job['status']?.toString()),
      backendCost: (job['totalCost'] as num?) ?? 0,
    );
  }

  bool get paid => status != OrderStatus.pending &&
      status != OrderStatus.cancelled &&
      status != OrderStatus.failed;

  /// Prefers the backend-computed cost; falls back to the local
  /// rate table only for orders that never reached the server.
  int get cost => backendCost > 0
      ? backendCost.round()
      : printCost(pages: pages, copies: copies, side: side);

  /// Sheets of paper used per copy (double-sided fits 2 pages per sheet).
  int get sheetsPerCopy => side == PrintSide.single ? pages : (pages + 1) ~/ 2;
}
