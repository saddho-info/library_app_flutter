import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/features/scan/presentation/scan_screen.dart';

void main() {
  testWidgets('manual entry field accepts a token and the button is idle', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScanScreen()));
    await tester.pump();

    expect(find.text('Look up copy'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.enterText(find.byType(TextField), 'qr-token-1');
    await tester.pump();

    expect(find.text('qr-token-1'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);
  });
}
