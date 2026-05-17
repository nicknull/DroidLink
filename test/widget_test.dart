import 'package:flutter_test/flutter_test.dart';
import 'package:android_manager/app.dart';

void main() {
  testWidgets('App renders splash view', (WidgetTester tester) async {
    await tester.pumpWidget(const DroidLinkApp());
    await tester.pump();
    expect(find.text('DroidLink'), findsOneWidget);
  });
}
