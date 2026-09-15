// Basic smoke test for OdontoControle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/main.dart';

void main() {
  testWidgets('ClinicApp builds without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ClinicApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
