import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/agrismartech_app.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AgrismartechApp());
    await tester.pumpAndSettle();

    expect(find.text('AgriSmart'), findsOneWidget);
    expect(find.text('Rice Disease Detector'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
