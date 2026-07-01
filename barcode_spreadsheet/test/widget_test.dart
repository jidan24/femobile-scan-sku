import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_spreadsheet/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const BarcodeToSheetsApp());
    expect(find.byType(BarcodeToSheetsApp), findsOneWidget);
  });
}
