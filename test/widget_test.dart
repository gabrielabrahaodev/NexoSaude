// Smoke test do boot do app com Firebase mockado (sem rede).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/main.dart';
import 'package:odonto_controle/screens/auth/role_check_screen.dart';
import 'package:odonto_controle/screens/auth/login_screen.dart';

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
  testWidgets('checagem de papel sem usuário retorna ao login após logout', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoleCheckScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
