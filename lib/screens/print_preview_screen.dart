import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../theme/app_theme.dart';
import '../utils/page_range.dart';
import '../widgets/fx.dart';

/// Shown right after "Place Print Order" is tapped. Lets the user see what
/// will actually be printed — real page content for PDFs and images, plus
/// an exact settings summary for every file type — before committing.
///
/// Pops with `true` if the user confirms, `false` on cancel/back. The
/// caller (`HomeTab._placeOrder`) only calls the create-job API when this
/// resolves to `true`.
class PrintPreviewScreen extends StatelessWidget {
  final String fileName;
  final Uint8List fileBytes;
  final int totalPages;
  final List<int>? selectedPages; // 1-based page numbers, null = all
  final int copies;
  final PrintSide side;
  final String? locationName;
  final String scheduleLabel;
  final int estimatedCost;

  const PrintPreviewScreen({
    super.key,
    required this.fileName,
    required this.fileBytes,
    required this.totalPages,
    required this.selectedPages,
    required this.copies,
    required this.side,
    required this.locationName,
    required this.scheduleLabel,
    required this.estimatedCost,
  });

  String get _extension =>
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

  int get _pageCount => selectedPages?.length ?? totalPages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  FadeSlideIn(child: _previewCard()),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 70),
                    child: _settingsCard(),
                  ),
                ],
              ),
            ),
            _actionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Pressable(
            pressedScale: 0.92,
            onTap: () => Navigator.of(context).pop(false),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.close_rounded, size: 22),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Print Preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _previewCard() {
    Widget preview;
    if (_extension == 'pdf') {
      // PdfPreview's `pages` is 0-based; selectedPages is 1-based sorted
      // page numbers (or null = every page) — this is the one and only
      // conversion site between the two conventions.
      preview = SizedBox(
        height: 460,
        child: PdfPreview(
          build: (format) async => fileBytes,
          pages: selectedPages?.map((p) => p - 1).toList(),
          useActions: false,
          canDebug: false,
          dpi: 120,
          scrollViewDecoration: const BoxDecoration(color: AppColors.chip),
          previewPageMargin:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          loadingWidget: const Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (_extension == 'jpg' || _extension == 'jpeg' || _extension == 'png') {
      preview = Container(
        height: 460,
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        color: AppColors.chip,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Image.memory(fileBytes, fit: BoxFit.contain),
        ),
      );
    } else {
      preview = Container(
        height: 220,
        alignment: Alignment.center,
        color: AppColors.chip,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Live preview isn't available for .$_extension files yet — "
                'double-check the settings below before confirming.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: preview,
      ),
    );
  }

  Widget _settingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecor.card(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _row(
            'Pages to print',
            selectedPages == null
                ? 'All $totalPages pages'
                : '${formatPageRange(selectedPages!)} ($_pageCount pages)',
          ),
          _row('Copies', '$copies'),
          _row('Side', side.label),
          _row(
            'Total sheets',
            '${side == PrintSide.single ? _pageCount : (_pageCount + 1) ~/ 2} × $copies',
          ),
          _row('Location', locationName ?? 'Not selected'),
          _row('Print time', scheduleLabel),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(
            children: [
              const Text(
                'Estimated Total',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                rupees(estimatedCost),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style:
                const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm & Print'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
