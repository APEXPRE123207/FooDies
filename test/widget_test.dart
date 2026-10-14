import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/app.dart';

void main() {
  testWidgets('FoodiesApp renders onboarding or home screen successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FoodiesApp(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify Foodies branding appears
    expect(find.text('FOODIES'), findsWidgets);
  });
}
