import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:print_service_app/models/print_order.dart';
import 'package:print_service_app/screens/orders_screen.dart';
import 'package:print_service_app/state/app_state.dart';
import 'package:print_service_app/theme/app_theme.dart';

PrintOrder _order(String ref, String name, String status, {int pages = 1, num cost = 2}) =>
    PrintOrder.fromJob({
      '_id': 'job-$ref',
      'referenceId': ref,
      'originalName': name,
      'status': status,
      'totalPagesToPrint': pages,
      'copies': 1,
      'printSide': 'SINGLE',
      'totalCost': cost,
      'createdAt': '2026-11-07T10:00:00Z',
    });

/// Renders the Orders tab like the website's Orders page. Set
/// ORDERS_TAB_PNG=/path.png to also save a screenshot for a visual check.
void main() {
  testWidgets('Orders tab shows the website layout: header, Active/History tabs, tickets',
      (tester) async {
    final font = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
    await tester.binding.setSurfaceSize(const Size(412, 892));
    tester.view.devicePixelRatio = 1;

    final state = AppState()
      ..orders = [
        _order('PJ-1A1B5D1821E-B494', 'Id card.pdf', 'PRINTING', cost: 42),
        _order('PJ-1A1B5C5682A-5523', 'Document from Praju.pdf', 'COMPLETED', pages: 4, cost: 28),
        _order('PJ-1A1B5B2A3CE-862E', 'combined-documents.pdf', 'CANCELLED'),
        _order('PJ-1A1B5ABCDC4-234C', 'combined-documents.pdf', 'PENDING'),
        _order('PJ-1A05719145B-24B9', '(3) Instagram.pdf', 'COLLECTED'),
      ];

    final boundary = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundary,
            child: const Scaffold(backgroundColor: AppColors.bg, body: OrdersTab()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YOUR PRINTS'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // active count (all but COLLECTED)
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Id card.pdf'), findsOneWidget);
    expect(find.text('₹42'), findsOneWidget);
    expect(find.text('(3) Instagram.pdf'), findsNothing); // collected → History

    final out = Platform.environment['ORDERS_TAB_PNG'];
    if (out != null) {
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('(3) Instagram.pdf'), findsOneWidget);
    expect(find.text('Id card.pdf'), findsNothing);
  });
}
