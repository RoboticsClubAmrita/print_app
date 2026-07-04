import 'package:flutter_test/flutter_test.dart';

import 'package:print_service_app/main.dart';

void main() {
  testWidgets('App launches to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PrintServiceApp());
    expect(find.text('Own Your\nPrints.'), findsOneWidget);
    expect(find.text('Explore Printing'), findsOneWidget);
  });
}
