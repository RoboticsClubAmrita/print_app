import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/print_order.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Reads back the document attached to an order.
///
/// Before payment clears the PDF is still on this device and is shown from
/// there; afterwards it comes from the print server, which only serves it to
/// the account that owns it and only until 24 hours after collection. Both
/// cases render identically — the user just sees their document.
class DocumentViewerScreen extends StatefulWidget {
  final PrintOrder order;

  const DocumentViewerScreen({super.key, required this.order});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await context.read<AppState>().documentBytesFor(widget.order);
      if (mounted) setState(() => _bytes = bytes);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not reach the print server. Check your connection and try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          widget.order.fileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: switch ((_bytes, _error)) {
        (_, final String message) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 34, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        (final Uint8List bytes, _) => PdfPreview(
            build: (_) => bytes,
            // Viewing only — printing and sharing a document the print shop is
            // already handling would just be a way to leak it off-device.
            allowPrinting: false,
            allowSharing: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
