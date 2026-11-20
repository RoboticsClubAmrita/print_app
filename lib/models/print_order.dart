import '../data/pricing.dart';

enum OrderStatus {
  pending,
  scheduled,
  queued,
  printing,
  awaitingStack,
  ready,
  collected,
  cancelled,
  failed,
}

enum PrintSide { single, double }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Awaiting Payment',
        OrderStatus.scheduled => 'Scheduled',
        OrderStatus.queued => 'Queued',
        OrderStatus.printing => 'Printing',
        OrderStatus.awaitingStack => 'Waiting for Pickup Slot',
        OrderStatus.ready => 'Ready to Collect',
        OrderStatus.collected => 'Collected',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.failed => 'Failed',
      };

  /// Maps the backend `Job.status` string to the app's [OrderStatus].
  ///
  /// `PRINTED_PENDING_STACK` means printing finished but no physical stack
  /// slot is free yet, so it's kept distinct from `COMPLETED` (truly ready
  /// to collect) — otherwise the app offers "Request Collection" for a job
  /// that isn't actually sitting in a stack, which the backend then rejects.
  static OrderStatus fromBackend(String? status) => switch (status) {
        'PENDING' => OrderStatus.pending,
        'SCHEDULED' => OrderStatus.scheduled,
        'QUEUED' => OrderStatus.queued,
        'PRINTING' => OrderStatus.printing,
        'PRINTED_PENDING_STACK' => OrderStatus.awaitingStack,
        'COMPLETED' => OrderStatus.ready,
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

  /// Backend document id. The key for both the copy still held on this device
  /// (order placed, payment not yet settled) and `/api/files/<id>/content`.
  final String fileId;

  /// True once the document has actually been uploaded, so it can be read back
  /// from the server. Null/false means it still lives only on this device.
  final bool documentStored;

  /// Whether the document can be opened right now. The backend decides this:
  /// it knows whether the file still exists and whether the 24-hour
  /// post-collection window has closed, neither of which is visible from
  /// [documentStored] alone. This is what the preview button is gated on.
  final bool documentAvailable;
  final String fileName;
  final int fileSizeKb;
  final int pages;
  final int copies;
  final PrintSide side;
  final DateTime createdAt;
  final DateTime scheduledAt;
  final bool scheduledNow;
  final num backendCost;

  /// Real per-page/sheet rate the backend charged (from `print_prices`),
  /// as opposed to the flat local estimate in `data/pricing.dart`.
  final num costPerPage;

  /// `copies * totalPagesToPrint * costPerPage` — the cost of this job
  /// alone, before any outstanding balance is rolled in.
  final num basePrintCost;

  /// Outstanding balance (e.g. uncollected-materials storage fees) that
  /// the backend added on top of [basePrintCost] to make up [backendCost].
  final num balanceApplied;

  final String colorMode; // BW | COLOR
  final String pageType; // A2 | A3 | A4

  /// 1-based selected page numbers, sorted; null means "all pages".
  final List<int>? selectedPages;

  /// Stack currently holding this job's material (set while COMPLETED).
  final String? stackName;

  /// Stack it was collected from — frozen at collection time, survives
  /// the stack being reused by a later job.
  final String? collectedStackName;

  final String scheduleType; // NOW | SCHEDULED
  final DateTime? scheduledFor;

  OrderStatus status;

  PrintOrder({
    required this.id,
    this.jobId = '',
    this.fileId = '',
    this.documentStored = false,
    this.documentAvailable = false,
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
    this.costPerPage = 0,
    this.basePrintCost = 0,
    this.balanceApplied = 0,
    this.colorMode = 'BW',
    this.pageType = 'A4',
    this.selectedPages,
    this.stackName,
    this.collectedStackName,
    this.scheduleType = 'NOW',
    this.scheduledFor,
  });

  factory PrintOrder.fromJob(Map<String, dynamic> job) {
    final createdAt =
        DateTime.tryParse(job['createdAt']?.toString() ?? '') ?? DateTime.now();
    final scheduleType = (job['scheduleType'] ?? 'NOW').toString();
    final scheduledFor = DateTime.tryParse(job['scheduledFor']?.toString() ?? '');
    final rawSelectedPages = job['selectedPages'];
    return PrintOrder(
      id: (job['referenceId'] ?? job['_id'] ?? '').toString(),
      jobId: (job['_id'] ?? '').toString(),
      fileId: (job['fileId'] ?? '').toString(),
      documentStored: (job['fileUploadStatus']?.toString() ?? '') == 'STORED',
      // Falls back to fileUrl so this still behaves against an older backend
      // that doesn't send fileIsViewable.
      documentAvailable: job['fileIsViewable'] == true ||
          (job['fileIsViewable'] == null && (job['fileUrl']?.toString().isNotEmpty ?? false)),
      fileName: (job['originalName'] ?? 'Document').toString(),
      fileSizeKb: 0,
      pages: (job['totalPagesToPrint'] as num?)?.toInt() ?? 0,
      copies: (job['copies'] as num?)?.toInt() ?? 1,
      side: PrintSideLabel.fromBackend(job['printSide']?.toString()),
      createdAt: createdAt,
      scheduledAt: scheduledFor ?? createdAt,
      scheduledNow: scheduleType != 'SCHEDULED',
      status: OrderStatusLabel.fromBackend(job['status']?.toString()),
      backendCost: (job['totalCost'] as num?) ?? 0,
      costPerPage: (job['costPerPage'] as num?) ?? 0,
      basePrintCost: (job['printCost'] as num?) ?? 0,
      balanceApplied: (job['balanceApplied'] as num?) ?? 0,
      colorMode: (job['colorMode'] ?? 'BW').toString(),
      pageType: (job['pageType'] ?? 'A4').toString(),
      selectedPages: rawSelectedPages is List
          ? rawSelectedPages.map((p) => (p as num).toInt()).toList()
          : null,
      stackName: job['stackName']?.toString(),
      collectedStackName: job['collectedStackName']?.toString(),
      scheduleType: scheduleType,
      scheduledFor: scheduledFor,
    );
  }

  bool get paid => status != OrderStatus.pending &&
      status != OrderStatus.cancelled &&
      status != OrderStatus.failed;

  /// Prefers the backend-computed cost; otherwise recomputes it from the
  /// rate the backend priced the order at.
  int get cost => backendCost > 0
      ? backendCost.round()
      : printCost(pages: pages, copies: copies, side: side, rate: costPerPage);

  /// Sheets of paper used per copy (double-sided fits 2 pages per sheet).
  int get sheetsPerCopy => side == PrintSide.single ? pages : (pages + 1) ~/ 2;

  String get colorModeLabel => colorMode == 'COLOR' ? 'Colour' : 'B&W';
}

/// "Stack A1" for a stack named "A1", but "Stack 2" (not "Stack Stack 2")
/// for one the admin already named "Stack 2".
String stackLabel(String name) {
  final trimmed = name.trim();
  return RegExp(r'^stack\b', caseSensitive: false).hasMatch(trimmed)
      ? trimmed
      : 'Stack $trimmed';
}
