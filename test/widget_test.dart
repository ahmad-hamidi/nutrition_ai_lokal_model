import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens_offline/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows app title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const NutriLensApp());
    expect(find.text('NutriLens Offline AI'), findsOneWidget);
  });
}
