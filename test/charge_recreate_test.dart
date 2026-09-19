import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/financial_service.dart';

void main() {
  group('FinancialService.recreatedData', () {
    Map<String, dynamic> cancelled() => {
          'clinicId': 'c1',
          'patientId': 'p1',
          'patientName': 'Teste',
          'title': 'Pacote Jan/2026 1/4',
          'amount': 500.0,
          'paidAmount': 500.0,
          'status': 'cancelado',
          'paymentMethod': 'Pix',
          'dueDate': 'mantido',
          'planId': 'plan1',
          'relatedBudgetId': 'b1',
          'installmentNumber': 'Jan/2026 1/4',
          'monthlyPeriod': '2026-01',
          'billingKind': 'package_monthly',
          'cancelledAt': 'ontem',
        };

    test('reseta quitação e volta a pendente', () {
      final r = FinancialService.recreatedData(cancelled());
      expect(r['status'], 'pendente');
      expect(r['paidAmount'], 0.0);
      expect(r['paymentDate'], isNull);
      expect(r['paymentMethod'], '');
      expect(r.containsKey('cancelledAt'), isFalse);
    });

    test('preserva vínculo e termos originais', () {
      final r = FinancialService.recreatedData(cancelled());
      expect(r['planId'], 'plan1');
      expect(r['relatedBudgetId'], 'b1');
      expect(r['installmentNumber'], 'Jan/2026 1/4');
      expect(r['monthlyPeriod'], '2026-01');
      expect(r['billingKind'], 'package_monthly');
      expect(r['dueDate'], 'mantido');
      expect(r['amount'], 500.0);
    });

    test('overrides trocam valor e vencimento', () {
      final due = DateTime(2026, 3, 10);
      final r = FinancialService.recreatedData(
        cancelled(),
        amount: 600.0,
        dueDate: due,
      );
      expect(r['amount'], 600.0);
      expect((r['dueDate'] as dynamic).toDate(), due);
      expect(r['status'], 'pendente');
      expect(r['planId'], 'plan1');
    });
  });
}
