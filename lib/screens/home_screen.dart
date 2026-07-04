import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dot_grid.dart';
import '../widgets/field_chip.dart';
import '../widgets/fx.dart';
import '../widgets/pill_toggle.dart';
import 'order_detail_screen.dart';

/// Home tab: dark hero header + the print order form card,
/// mirroring the flight booking reference layout.
class HomeTab extends StatefulWidget {
  final VoidCallback onViewOrders;

  const HomeTab({super.key, required this.onViewOrders});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _fileName;
  int _fileSizeKb = 0;
  int _pages = 1;
  int _copies = 1;
  int _sideIndex = 0;
  DateTime? _scheduledAt;
  bool _picking = false;

  PrintSide get _side => _sideIndex == 0 ? PrintSide.single : PrintSide.double;

  int get _estimate => printCost(pages: _pages, copies: _copies, side: _side);

  Future<void> _pickFile() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      if (result != null && result.files.isNotEmpty && mounted) {
        final f = result.files.first;
        setState(() {
          _fileName = f.name;
          _fileSizeKb = (f.size / 1024).ceil();
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
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
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
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

  void _placeOrder() {
    if (_fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a document to print first')),
      );
      return;
    }
    final order = context.read<AppState>().placeOrder(
          fileName: _fileName!,
          fileSizeKb: _fileSizeKb,
          pages: _pages,
          copies: _copies,
          side: _side,
          scheduledAt: _scheduledAt,
        );
    setState(() {
      _fileName = null;
      _fileSizeKb = 0;
      _pages = 1;
      _copies = 1;
      _sideIndex = 0;
      _scheduledAt = null;
    });
    showSuccessOverlay(
      context,
      title: 'Order Placed',
      subtitle: '${order.id} • ${order.fileName}',
      icon: Icons.print_rounded,
    ).then((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final firstName = state.user?.name.split(' ').first ?? 'there';
    final schedLabel = _scheduledAt == null
        ? 'Now'
        : DateFormat('MMM d • h:mm a').format(_scheduledAt!);

    return ListView(
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
            child: _todaySection(state),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: AppColors.white, size: 15),
                            SizedBox(width: 6),
                            Text(
                              'Campus Print Hub',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
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
                      const SizedBox(width: 10),
                      Container(
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
          PillToggle(
            options: const ['Single-sided', 'Double-sided'],
            selectedIndex: _sideIndex,
            onChanged: (i) => setState(() => _sideIndex = i),
          ),
          const SizedBox(height: 14),
          FieldChip(
            label:
                _fileName == null ? 'Document' : 'Document • $_fileSizeKb KB',
            value: _fileName ?? 'Tap to upload a file',
            valueIsPlaceholder: _fileName == null,
            trailingIcon: Icons.upload_file_rounded,
            onTap: _pickFile,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StepperChip(
                  label: 'Pages',
                  value: _pages,
                  onChanged: (v) => setState(() => _pages = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StepperChip(
                  label: 'Copies',
                  value: _copies,
                  onChanged: (v) => setState(() => _copies = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FieldChip(
            label: 'Print Time',
            value: schedLabel,
            trailingIcon: Icons.schedule_rounded,
            onTap: _pickSchedule,
          ),
          const SizedBox(height: 16),
          Container(
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
                    rateLabel(_side),
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
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _placeOrder,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Place Print Order'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
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

/// A tiny colored dot indicating order status, used on the compact
/// "Today's Prints" cards where a full status chip would be too heavy.
class _StatusDot extends StatelessWidget {
  final OrderStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.queued => AppColors.textSecondary,
      OrderStatus.printing => AppColors.warning,
      OrderStatus.ready => AppColors.success,
      OrderStatus.collected => AppColors.success,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
