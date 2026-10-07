import 'package:flutter_test/flutter_test.dart';

import 'package:boutix/app.dart';

void main() {
  testWidgets('Boutix app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BoutixApp());
    expect(find.textContaining('BOUTIX'), findsWidgets);
  });
}
