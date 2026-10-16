// Smoke test do boot do app com Firebase mockado (sem rede).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('ClinicApp builds without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ClinicApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
