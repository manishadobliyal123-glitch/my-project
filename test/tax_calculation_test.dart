import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tax/main.dart';

void main() {
  group('Uttarakhand Tax App Tests', () {
    testWidgets('App renders header and title correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const UttarakhandTaxApp());
      expect(find.text('Uttarakhand Property Tax Calculator'), findsWidgets);
      expect(find.text('Property Tax Calculator'), findsOneWidget);
      expect(find.text('Calculate Tax'), findsOneWidget);
    });

    testWidgets('Calculate button calculates and displays net tax', (WidgetTester tester) async {
      await tester.pumpWidget(const UttarakhandTaxApp());

      // Scroll to Calculate Tax button and tap
      final calculateButton = find.text('Calculate Tax');
      expect(calculateButton, findsOneWidget);
      await tester.ensureVisible(calculateButton);
      await tester.pumpAndSettle();

      await tester.tap(calculateButton);
      await tester.pumpAndSettle();

      // Verify Result Card is displayed with 'Estimated Annual Property Tax'
      expect(find.text('Estimated Annual Property Tax'), findsOneWidget);
      expect(find.text('Calculation Breakdown'), findsOneWidget);
    });
  });
}
