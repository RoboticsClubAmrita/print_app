import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdf_combiner/models/merge_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../services/api_client.dart';
import '../services/document_prep.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/page_range.dart';
import '../widgets/dot_grid.dart';
import '../widgets/field_chip.dart';
import '../widgets/fx.dart';
import '../widgets/pill_toggle.dart';
import 'order_detail_screen.dart';
import 'print_preview_screen.dart';
import '../widgets/showcase_next_button.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onViewOrders;
  final VoidCallback onViewProfile;
  final GlobalKey bottomNavKey;
  final bool demoMode;

  const HomeTab({
    super.key,
    required this.onViewOrders,
    required this.onViewProfile,
    required this.bottomNavKey,
    this.demoMode = false,
  });

  @override
  State<HomeTab> createState() => HomeTabState();
}

/// Extensions the backend's upload filter accepts (see
/// print_backend/utils/uploadHelper.js) — PDFs, Word docs, and images.
/// Formats the picker offers. Word/PowerPoint are absent on purpose — see
/// document_prep.dart: a phone can't convert them faithfully, and an
/// approximate conversion means the preview, page count and printout disagree.
const _kPrintableExtensions = kPrintableExtensions;

class HomeTabState extends State<HomeTab> {
  String? _fileName;
  Uint8List? _fileBytes;
  List<PlatformFile> _selectedSourceFiles = [];
  int _fileSizeKb = 0;
  String? _fileId;
  int? _detectedPages;
  List<int>? _selectedPages; // null = every page
  int _copies = 1;
  int _sideIndex = 0;
  DateTime? _scheduledAt;
  bool _picking = false;
  bool _uploading = false;
  bool _placing = false;

  /// Real per-page rate from the backend's pricing table (A4/BW — the
  /// only size/color this form offers) — replaces the flat local
  /// estimate so the shown price always matches what's actually billed.
  num? _ratePerPage;

  // ---------------- First-time feature tour ----------------
  final _tourLocation = GlobalKey();

  final _tourToggle = GlobalKey();
  final _tourDocument = GlobalKey();
  final _tourPages = GlobalKey();
  final _tourCopies = GlobalKey();
  final _tourPrintTime = GlobalKey();
  final _tourTotal = GlobalKey();
  final _tourPlaceOrder = GlobalKey();
  final _tourTodaysPrints = GlobalKey();

  // Every showcase step scrolls the page to bring its target into view
  // before highlighting it, so steps further down (Estimated Total, Place
  // Order, etc.) are always reachable regardless of scroll position when
  // the tour starts.
  static const _tourScrollDuration = Duration(milliseconds: 300);

  final _scrollController = ScrollController();

  /// Bring a coach-mark target into view for the tour.
  ///
  /// The package's own `enableAutoScroll` is off because it positions by
  /// *layout*, and the order form is painted 46px above where it lays out
  /// (`Transform.translate` in [build]). That mismatch is what made the
  /// mid-form steps scroll into place and then visibly correct themselves.
  ///
  /// `localToGlobal` reports the *painted* position — it walks the same
  /// transforms the highlight does — so measuring with it keeps the scroll
  /// and the spotlight in agreement no matter what offsets the layout uses.
  Future<void> scrollTourTargetIntoView(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null || !_scrollController.hasClients) return;

    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final position = _scrollController.position;
    final paintedTop = box.localToGlobal(Offset.zero).dy;
    final viewport = position.viewportDimension;

    // Centre the target, but never fight the ends of the list.
    final desiredTop = (viewport - box.size.height) / 2;
    final target = (position.pixels + (paintedTop - desiredTop))
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((target - position.pixels).abs() < 1) return;

    await _scrollController.animateTo(
      target,
      duration: _tourScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  PrintSide get _side => _sideIndex == 0 ? PrintSide.single : PrintSide.double;

  int get _selectedPageCount => _selectedPages?.length ?? (_detectedPages ?? 0);

  int get _estimate => _ratePerPage != null
      ? (_ratePerPage! * _selectedPageCount * _copies).round()
      : printCost(pages: _selectedPageCount, copies: _copies, side: _side);




  /// Page count for the demo order. Uses the same counter the real flow does,
  /// so the demo can't show a number the live path would refuse to produce.
  Future<int> _detectPagesForDemo(Uint8List bytes, String extension) async {
    if (extension != 'pdf') return 1;
    try {
      return await countPdfPages(bytes);
    } on PageDetectionException {
      return 1;
    }
  }

  Future<void> _loadRate() async {
    try {
      final rate = await ApiClient.pricingLookup(
        size: 'A4',
        type: 'bw',
        side: _side == PrintSide.single ? 'single' : 'double',
      );
      if (mounted) setState(() => _ratePerPage = rate);
    } catch (_) {
      // Non-critical — falls back to the local flat-rate estimate.
    }
  }

  /// Showcase keys in tour order, contributed to the single combined tour
  /// list assembled by [ShellScreen._startFullTour]. The bottom-nav coach
  /// mark is owned by [ShellScreen] itself and inserted right after these.
  List<GlobalKey> get tourKeys => [
        _tourLocation,
        _tourToggle,
        _tourDocument,
        _tourPages,
        _tourCopies,
        _tourPrintTime,
        _tourTotal,
        _tourPlaceOrder,
        _tourTodaysPrints,
      ];

  Future<void> _pickPageRange() async {
    if (_detectedPages == null) return;
    final controller = TextEditingController(
      text: _selectedPages == null ? '' : formatPageRange(_selectedPages!),
    );
    String? error;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Choose pages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This document has $_detectedPages pages.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. 1-5, 8, 11-13',
                  helperText: 'Leave blank for all pages',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final pages = parsePageRange(controller.text, _detectedPages!);
                  Navigator.of(dialogContext).pop(pages);
                } on FormatException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedPages = result.length == _detectedPages ? null : result;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      _ratePerPage = 2;
      return;
    }
    final state = context.read<AppState>();
    if (state.locations.isEmpty) state.loadLocations();
    _loadRate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    if (widget.demoMode) {
      context.read<AppState>().selectLocation('demo-loc', 'Main Library Stack');
      return;
    }
    final state = context.read<AppState>();
    if (state.locations.isEmpty) await state.loadLocations();
    if (!mounted) return;
    if (state.locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No print locations available yet')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a print location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              for (final loc in state.locations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_rounded),
                  title: Text((loc['name'] ?? 'Location').toString()),
                  onTap: () {
                    state.selectLocation(
                      (loc['_id'] ?? '').toString(),
                      (loc['name'] ?? 'Location').toString(),
                    );
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications() {
    final notifications = context.read<AppState>().notifications;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final n = notifications[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(n.body,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, h:mm a').format(n.time),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDocumentPicker() async {
    if (_picking || _uploading) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose multiple files or select a folder. PDF and image files are merged into one PDF.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: const Icon(Icons.file_copy_outlined),
                label: const Text('Choose files'),
                onPressed: () => Navigator.of(sheetContext).pop('files'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Choose folder'),
                onPressed: () => Navigator.of(sheetContext).pop('folder'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'folder') {
      await _pickFolder();
    } else {
      await _pickFiles();
    }
  }

  Future<void> _pickFiles() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      if (widget.demoMode) {
        final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.any);
        if (result != null && result.files.isNotEmpty && mounted) {
          final f = result.files.first;
          if (f.bytes == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read that file')),
            );
          } else {
            setState(() {
              _fileName = f.name;
              _fileBytes = f.bytes;
              _fileSizeKb = (f.size / 1024).ceil();
              _fileId = null;
              _detectedPages = null;
              _selectedPages = null;
              _uploading = true;
            });
            final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
            final pages = await _detectPagesForDemo(f.bytes!, ext);
            if (!mounted) return;
            setState(() {
              _fileId = 'demo-file';
              _detectedPages = pages;
              _uploading = false;
            });
          }
        }
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _kPrintableExtensions,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      await _prepareSelectedFiles(result.files);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickFolder() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath();
      if (folderPath == null || !mounted) return;
      final directory = Directory(folderPath);
      if (!await directory.exists()) {
        throw const FileSystemException('The selected folder could not be opened.');
      }

      final files = <PlatformFile>[];
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last;
        final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
        if (!_kPrintableExtensions.contains(extension)) continue;
        final bytes = await entity.readAsBytes();
        files.add(PlatformFile(name: name, size: bytes.length, path: entity.path, bytes: bytes));
      }

      if (!mounted) return;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The selected folder has no supported documents.')),
        );
        return;
      }
      await _prepareSelectedFiles(files);
    } on FileSystemException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This device did not provide access to that folder. Choose multiple files instead.')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _prepareSelectedFiles(List<PlatformFile> pickedFiles) async {
    final unique = <String, PlatformFile>{};
    for (final file in [..._selectedSourceFiles, ...pickedFiles]) {
      final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
      if (!_kPrintableExtensions.contains(extension)) continue;
      unique['${file.name}:${file.size}:${file.path ?? ''}'] = file;
    }

    final selected = unique.values.toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No supported files were selected.')),
      );
      return;
    }

    // Everything must be convertible to PDF here — nothing goes to the server
    // in any other format, and the page count has to come off a real PDF.
    try {
      assertAllPrintable(selected.map((file) => file.name));
    } on DocumentPrepException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    final readableFiles = <PlatformFile>[];
    for (final file in selected) {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) bytes = await File(file.path!).readAsBytes();
      if (bytes == null) throw StateError('Could not read ${file.name}');
      readableFiles.add(PlatformFile(name: file.name, size: bytes.length, path: file.path, bytes: bytes));
    }

    setState(() {
      _selectedSourceFiles = readableFiles;
      _fileName = readableFiles.length == 1 ? readableFiles.first.name : 'combined-documents.pdf';
      _fileId = null;
      _detectedPages = null;
      _selectedPages = null;
    });
    await _mergeAndUploadSelected();
  }

  Future<void> _mergeAndUploadSelected() async {
    if (_selectedSourceFiles.isEmpty) return;
    setState(() => _uploading = true);
    try {
      Uint8List finalBytes;
      String finalName;

      if (_selectedSourceFiles.length == 1 && _selectedSourceFiles.first.name.toLowerCase().endsWith('.pdf')) {
        finalBytes = _selectedSourceFiles.first.bytes!;
        finalName = _selectedSourceFiles.first.name;
      } else {
        final tempDirectory = await getTemporaryDirectory();
        final outputPath = '${tempDirectory.path}${Platform.pathSeparator}combined-documents-${DateTime.now().millisecondsSinceEpoch}.pdf';
        final inputs = _selectedSourceFiles.map((file) => MergeInput.bytes(file.bytes!)).toList();
        final generatedPath = await PdfCombiner.generatePDFFromDocuments(inputs: inputs, outputPath: outputPath);
        finalBytes = await File(generatedPath).readAsBytes();
        finalName = 'combined-documents.pdf';
      }

      // Count the pages and fingerprint the merged PDF. This is the number the
      // order is billed on and the digest the backend re-checks after payment,
      // so a document whose pages can't be read is refused outright rather
      // than being ordered against a guess.
      final prepared = await describeDocument(bytes: finalBytes, fileName: finalName);

      if (!mounted) return;
      setState(() {
        _fileName = prepared.fileName;
        _fileBytes = prepared.bytes;
        _fileSizeKb = prepared.sizeKb;
        _detectedPages = prepared.totalPages;
      });
      await _registerPrepared(prepared);
    } on PageDetectionException catch (e) {
      if (mounted) {
        _resetDocument();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploading failed — ${e.message}. Try re-saving it as a PDF.')),
        );
      }
    } on DocumentPrepException catch (e) {
      if (mounted) {
        _resetDocument();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (error) {
      if (mounted) {
        _resetDocument();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare the selected documents: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Tells the backend what we are about to print — name, size, sha256 and
  /// page count — so the order can be priced. The PDF itself stays on this
  /// device and is only sent once the order has been paid for.
  Future<void> _registerPrepared(PreparedDocument prepared) async {
    final state = context.read<AppState>();
    if (!mounted) return;

    try {
      final fileId = await state.registerDocument(prepared);
      if (!mounted) return;
      setState(() => _fileId = fileId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach the print server. Check your connection and try again.')),
        );
      }
    }
  }

  /// Clears the picked document and every piece of state derived from it.
  /// Print settings (copies, side, schedule) are intentionally preserved —
  /// they aren't document-derived. `_estimate` follows automatically, and
  /// `_ratePerPage` is keyed on side rather than the file, so it stays.
  void _resetDocument() {
    _selectedSourceFiles = [];
    _fileName = null;
    _fileBytes = null;
    _fileSizeKb = 0;
    _fileId = null;
    _detectedPages = null;
    _selectedPages = null;
  }

  void _removeDocument() {
    HapticFeedback.selectionClick();
    setState(_resetDocument);
  }

  Future<void> _pickSchedule() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'When should we print?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: const Text('Print Now'),
                onPressed: () => Navigator.of(sheetContext).pop('now'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded, size: 20),
                label: const Text('Schedule for Later'),
                onPressed: () => Navigator.of(sheetContext).pop('later'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'now') {
      setState(() => _scheduledAt = null);
      return;
    }
    final now = DateTime.now();
    final maxDays = context.read<AppState>().maxScheduleDaysAhead;
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(Duration(days: maxDays)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _placeOrder() async {
    if (_fileName == null || _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a document to print first')),
      );
      return;
    }
    if (_uploading || _fileId == null || _detectedPages == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still counting pages — try again in a moment')),
      );
      return;
    }
    if (_placing) return;

    final state = context.read<AppState>();
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrintPreviewScreen(
          fileName: _fileName!,
          fileBytes: _fileBytes!,
          totalPages: _detectedPages!,
          selectedPages: _selectedPages,
          copies: _copies,
          side: _side,
          locationName: state.selectedLocationName,
          scheduleLabel: _scheduledAt == null
              ? 'Now'
              : DateFormat('MMM d • h:mm a').format(_scheduledAt!),
          estimatedCost: _estimate,
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _placing = true);

    if (widget.demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      context.read<AppState>().injectDemoOrder(
            PrintOrder(
              id: 'DEMO-0001',
              jobId: AppState.kDemoJobId,
              fileName: _fileName!,
              fileSizeKb: _fileSizeKb,
              pages: _selectedPageCount,
              copies: _copies,
              side: _side,
              createdAt: DateTime.now(),
              scheduledAt: _scheduledAt ?? DateTime.now(),
              scheduledNow: _scheduledAt == null,
              status: OrderStatus.pending,
              backendCost: _estimate,
              selectedPages: _selectedPages,
            ),
          );
      setState(() {
        _resetDocument();
        _copies = 1;
        _sideIndex = 0;
        _scheduledAt = null;
        _placing = false;
      });
      widget.onViewOrders();
      return;
    }

    try {
      final order = await context.read<AppState>().placeOrder(
            fileId: _fileId!,
            pages: _selectedPageCount,
            copies: _copies,
            side: _side,
            selectedPages: _selectedPages,
            scheduledFor: _scheduledAt,
          );
      if (!mounted) return;
      setState(() {
        _resetDocument();
        _copies = 1;
        _sideIndex = 0;
        _scheduledAt = null;
      });
      await showSuccessOverlay(
        context,
        title: 'Order Placed',
        subtitle: '${order.id} • ${order.fileName}',
        icon: Icons.print_rounded,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not place the order. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final firstName = state.user?.name.split(' ').first ?? 'there';
    final schedLabel = _scheduledAt == null
        ? 'Now'
        : DateFormat('MMM d • h:mm a').format(_scheduledAt!);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        FadeSlideIn(
          from: const Offset(0, -0.03),
          child: _header(context, firstName),
        ),
        Transform.translate(
          offset: const Offset(0, -46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _orderForm(schedLabel),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -26),
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: AppShowcase(
              key: _tourTodaysPrints,
              title: "Today's Prints",
              description:
                  "Everything you've printed today, at a glance.",
              targetShapeBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              tooltipActions: nextTooltipActions(context, step: 9, total: 10),
              tooltipActionConfig: tooltipNextActionConfig,
              child: _todaySection(state),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String firstName) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: Container(
        color: AppColors.black,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DotGrid(color: Colors.white10, spacing: 26, radius: 1.3),
            ),
            Positioned(
              right: -34,
              top: 30,
              child: Icon(
                Icons.print_rounded,
                size: 190,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 18,
                20,
                72,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppShowcase(
                        key: _tourLocation,
                        title: 'Choose Your Location',
                        description:
                            'Tap here to pick which print stack should receive your order.',
                        targetShapeBorder: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        tooltipActions:
                            nextTooltipActions(context, step: 1, total: 10),
                        tooltipActionConfig: tooltipNextActionConfig,
                        child: Pressable(
                          onTap: _pickLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white12, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: AppColors.white, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  context.watch<AppState>().selectedLocationName ??
                                      'Choose Location',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white54, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: _showNotifications,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: widget.onViewProfile,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.white,
                            child: Text(
                              context.watch<AppState>().user?.initials ?? '?',
                              style: const TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'Hi $firstName 👋',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Print Your\nDocs Here!',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 38,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderForm(String schedLabel) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
         Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppColors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Print Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Set it up in seconds',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppShowcase(
            key: _tourToggle,
            title: 'Single or Double-Sided',
            description:
                'Double-sided fits two pages per sheet — cheaper and greener for long documents.',
            targetShapeBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            tooltipActions: nextTooltipActions(context, step: 2, total: 10),
            tooltipActionConfig: tooltipNextActionConfig,
            child: PillToggle(
              options: const ['Single-sided', 'Double-sided'],
              selectedIndex: _sideIndex,
              onChanged: (i) {
                setState(() => _sideIndex = i);
                _loadRate();
              },
            ),
          ),
          const SizedBox(height: 14),
          if (widget.demoMode && _fileName == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.black, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.black),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Upload a file from your device to start the demo',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          AppShowcase(
            key: _tourDocument,
            title: 'Upload Your Document',
            description:
                'Pick any PDF, Word doc or image — we detect the page count instantly.',
            targetShapeBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            tooltipActions: nextTooltipActions(context, step: 3, total: 10),
            tooltipActionConfig: tooltipNextActionConfig,
            child: AnimatedGlowBorder(
              active: _uploading,
              radius: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  FieldChip(
                    label: _fileName == null
                        ? 'Documents'
                        : '${_selectedSourceFiles.length} file${_selectedSourceFiles.length == 1 ? '' : 's'} • $_fileSizeKb KB',
                    value: _fileName ?? 'Tap to choose files or a folder',
                    valueIsPlaceholder: _fileName == null,
                    trailingIcon: Icons.upload_file_rounded,
                    onTap: _uploading ? null : _showDocumentPicker,
                  ),
                  if (_fileName != null && !_uploading)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: _RemoveDocumentButton(onTap: _removeDocument),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppShowcase(
                  key: _tourPages,
                  title: 'Pick Specific Pages',
                  description:
                      'Print every page, or tap in to choose a custom range like 1-5, 8.',
                  targetShapeBorder: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  tooltipActions: nextTooltipActions(context, step: 4, total: 10),
                  tooltipActionConfig: tooltipNextActionConfig,
                  child: FieldChip(
                    label: 'Pages',
                    value: _uploading
                        ? 'Counting…'
                        : _detectedPages == null
                            ? '—'
                            : _selectedPages == null
                                ? 'All ($_detectedPages)'
                                : '${_selectedPages!.length} of $_detectedPages',
                    valueIsPlaceholder: _detectedPages == null,
                    trailingIcon: Icons.edit_note_rounded,
                    onTap: _detectedPages == null ? null : _pickPageRange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppShowcase(
                  key: _tourCopies,
                  title: 'Set Your Copies',
                  description: 'Use + and – to change how many copies you need.',
                  targetShapeBorder: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  tooltipActions: nextTooltipActions(context, step: 5, total: 10),
                  tooltipActionConfig: tooltipNextActionConfig,
                  child: StepperChip(
                    label: 'Copies',
                    value: _copies,
                    onChanged: (v) => setState(() => _copies = v),
                  ),
                ),
              ),
            ],
          ),
          if (_detectedPages != null) ...[
            const SizedBox(height: 10),
            Text(
              _selectedPages == null
                  ? 'Printing all $_detectedPages pages × $_copies ${_copies > 1 ? 'copies' : 'copy'}'
                  : 'Printing pages ${formatPageRange(_selectedPages!)} '
                      '(${_selectedPages!.length} pages) × $_copies '
                      '${_copies > 1 ? 'copies' : 'copy'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppShowcase(
            key: _tourPrintTime,
            title: 'Choose When to Print',
            description:
                'Print right now, or schedule your order for a later time.',
            targetShapeBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            tooltipActions: nextTooltipActions(context, step: 6, total: 10),
            tooltipActionConfig: tooltipNextActionConfig,
            child: FieldChip(
              label: 'Print Time',
              value: schedLabel,
              trailingIcon: Icons.schedule_rounded,
              onTap: _pickSchedule,
            ),
          ),
          const SizedBox(height: 16),
          AppShowcase(
            key: _tourTotal,
            title: 'Estimated Total',
            description:
                'Your live cost updates instantly as you adjust pages, copies and sides.',
            targetShapeBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            tooltipActions: nextTooltipActions(context, step: 7, total: 10),
            tooltipActionConfig: tooltipNextActionConfig,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Total',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedCount(
                          value: _estimate,
                          format: rupees,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.black,
                            fontFamily: kFontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _ratePerPage != null
                          ? '₹$_ratePerPage / page'
                          : rateLabel(_side),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppShowcase(
            key: _tourPlaceOrder,
            title: 'Place Your Order',
            description:
                "When you're ready, tap here to review and confirm your print job.",
            targetShapeBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            tooltipActions: nextTooltipActions(context, step: 8, total: 10),
            tooltipActionConfig: tooltipNextActionConfig,
            child: FilledButton(
              onPressed: (_placing || _uploading) ? null : _placeOrder,
              child: _placing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Place Print Order'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'ppt' || 'pptx' => Icons.slideshow_outlined,
      'doc' || 'docx' => Icons.article_outlined,
      'jpg' || 'jpeg' || 'png' => Icons.image_outlined,
      _ => Icons.description_outlined,
    };
  }

  Widget _todaySection(AppState state) {
    final today = state.todayOrders;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Today's Prints",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Pressable(
                onTap: widget.onViewOrders,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (today.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppDecor.card(radius: 22),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.chip,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nothing printed today',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your first order of the day is one tap away.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 106,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: today.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final o = today[i];
                  return Pressable(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: o.id),
                      ),
                    ),
                    child: Container(
                      width: 250,
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecor.card(radius: 22),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppDecor.darkPanelGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _fileIcon(o.fileName),
                              size: 22,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _StatusDot(status: o.status),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '${o.pages}pg × ${o.copies} • ${o.status.label}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  rupees(o.cost),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular remove affordance for the document chip. Uses [Material] +
/// [InkWell] rather than [Pressable]/[GestureDetector] so it carries hover
/// and focus states as well as the tap ripple.
///
/// The 40x40 box is deliberately larger than the 28px circle and aligns it
/// to the top-right: the badge is positioned to overhang the chip's corner,
/// and pixels outside the parent [Stack] can't be hit-tested, so the extra
/// box keeps ~35x35 of live tap target inside the chip.
class _RemoveDocumentButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveDocumentButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Align(
        alignment: Alignment.topRight,
        child: Tooltip(
          message: 'Remove document',
          child: Material(
            color: AppColors.white,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            shape: CircleBorder(
              side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.close_rounded, size: 16, color: AppColors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tiny colored dot indicating order status, used on the compact
/// "Today's Prints" cards where a full status chip would be too heavy.
class _StatusDot extends StatelessWidget {
  final OrderStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => AppColors.warning,
      OrderStatus.scheduled => AppColors.textSecondary,
      OrderStatus.queued => AppColors.textSecondary,
      OrderStatus.printing => AppColors.warning,
      OrderStatus.awaitingStack => AppColors.warning,
      OrderStatus.ready => AppColors.success,
      OrderStatus.collected => AppColors.success,
      OrderStatus.cancelled => AppColors.textSecondary,
      OrderStatus.failed => AppColors.warning,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
