import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/screens/financial/widgets/monthly_package_card.dart';

/// Gate anti-cobrança no cheio (reavaliação §10): com erro de cálculo, o
/// card mostra "sem cobrança" e o toque SÓ recalcula (nunca cobra).
void main() {
  Future<void> pumpErrorCard(WidgetTester tester, VoidCallback onTap) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MonthlyPackageCard(
          patientName: 'Paciente X',
          periodLabel: 'out/2026',
          installmentNumber: '1/1',
          sessionCount: 4,
          dueDate: DateTime(2026, 11, 10),
          totalAmount: 400.0,
          fullAmount: 400.0,
          billingDetail:
              'Cálculo indisponível no momento — toque para tentar de novo (sem cobrança)',
          contactedToday: false,
          onTap: onTap,
        ),
      ),
    ));
  }

  testWidgets('erro de cálculo mostra aviso sem cobrança e toque recalcula',
      (tester) async {
    var taps = 0;
    await pumpErrorCard(tester, () => taps++);
    expect(find.textContaining('sem cobrança'), findsOneWidget);
    // Não exibe valor cheio como "de ..." indevido nem skeleton travado.
    expect(find.textContaining('Cálculo indisponível'), findsOneWidget);
    await tester.tap(find.byType(MonthlyPackageCard));
    expect(taps, 1);
  });
}
