import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tax/main.dart';

void main() {
  testWidgets('Uttarakhand Tax App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UttarakhandTaxApp());
    expect(find.text('Uttarakhand Property Tax Calculator'), findsWidgets);
  });
}
