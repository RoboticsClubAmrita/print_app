import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_service_app/widgets/coach_tour.dart';

/// Pumps a page with three targets and a button that starts the tour,
/// recording how it ended in [results].
Future<List<GlobalKey>> _pumpHost(
  WidgetTester tester,
  List<TourResult> results,
) async {
  final keys = List.generate(3, (_) => GlobalKey());
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < keys.length; i++)
                KeyedSubtree(
                  key: keys[i],
                  child: SizedBox(height: 60, child: Text('Target $i')),
                ),
              ElevatedButton(
                onPressed: () async {
                  final ids = tourOrder.take(keys.length).toList();
                  results.add(await CoachTour.show(context, [
                    for (var i = 0; i < ids.length; i++)
                      TourStep(
                        target: keys[i],
                        title: tourCopy[ids[i]]!.$1,
                        description: tourCopy[ids[i]]!.$2,
                      ),
                  ]));
                },
                child: const Text('start'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
  return keys;
}

void main() {
  test('uses the website walkthrough copy, in the website order', () {
    expect(tourOrder.length, 9);
    expect(tourOrder.first, 'tour-upload');
    expect(tourOrder.last, 'tour-nav');
    for (final id in tourOrder) {
      expect(tourCopy[id], isNotNull, reason: id);
    }
    expect(tourCopy['tour-location']!.$2, 'Pick which print stack should receive your order.');
  });

  testWidgets('shows title, description and counter; Next/Back move between steps',
      (tester) async {
    final results = <TourResult>[];
    await _pumpHost(tester, results);

    expect(find.text('Upload Your Document'), findsOneWidget);
    expect(find.textContaining('we detect the page count instantly'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Back'), findsNothing); // no Back on the first step

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Single or Double-Sided'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Upload Your Document'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('Done on the last step reports finished', (tester) async {
    final results = <TourResult>[];
    await _pumpHost(tester, results);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(results, [TourResult.finished]);
    expect(find.text('Pick Specific Pages'), findsNothing);
  });

  testWidgets('the cross skips', (tester) async {
    final results = <TourResult>[];
    await _pumpHost(tester, results);

    await tester.tap(find.bySemanticsLabel('Skip the walkthrough'));
    await tester.pumpAndSettle();
    expect(results, [TourResult.skipped]);
  });

  testWidgets('tapping the dimmed area does not end the tour', (tester) async {
    final results = <TourResult>[];
    await _pumpHost(tester, results);

    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.text('Upload Your Document'), findsOneWidget);
  });

  testWidgets('after a step change the cutout lands exactly on the new target',
      (tester) async {
    // Regression: the glide stopped one frame early, so with slow frames the
    // spotlight froze well short of the target.
    final results = <TourResult>[];
    final keys = await _pumpHost(tester, results);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final target = tester.getRect(find.byKey(keys[1]));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CustomPainter>()
        .firstWhere((p) => p.runtimeType.toString() == '_MaskPainter');
    // ignore: avoid_dynamic_calls
    final Rect drawn = (painter as dynamic).target as Rect;
    expect(drawn, target);
  });

  testWidgets('the system back button skips', (tester) async {
    final results = <TourResult>[];
    await _pumpHost(tester, results);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, [TourResult.skipped]);
  });
}