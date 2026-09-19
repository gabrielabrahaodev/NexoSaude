import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/financial_model.dart';

void main() {
  group('FinancialModel.isPaidOf — definição única', () {
    test('status pagos (qualquer caixa)', () {
      for (final s in [
        'paid',
        'PAID',
        'pago',
        'Pago',
        'anticipated',
        'antecipado',
        'quitado',
        'recebido'
      ]) {
        expect(
          FinancialModel.isPaidOf(
              status: s, paidAmount: 0, amount: 500),
          isTrue,
          reason: s,
        );
      }
    });

    test('status não-pagos com paidAmount zerado', () {
      for (final s in ['pending', 'pendente', 'cobrado', 'cancelado', '']) {
        expect(
          FinancialModel.isPaidOf(
              status: s, paidAmount: 0, amount: 500),
          isFalse,
          reason: s,
        );
      }
    });

    test('quitação por valor cobre qualquer status', () {
      expect(
        FinancialModel.isPaidOf(
            status: 'pendente', paidAmount: 500, amount: 500),
        isTrue,
      );
      expect(
        FinancialModel.isPaidOf(
            status: 'pendente', paidAmount: 200, amount: 500),
        isFalse,
      );
    });

    test('valor zerado nunca conta como pago', () {
      expect(
        FinancialModel.isPaidOf(
            status: 'pendente', paidAmount: 0, amount: 0),
        isFalse,
      );
    });

    test('getter delega para a definição única', () {
      final m = FinancialModel(
        id: 'x',
        clinicId: 'c',
        patientId: 'p',
        patientName: 'T',
        title: 't',
        description: '',
        amount: 500,
        date: DateTime(2026, 1, 1),
        type: 'income',
        status: 'pago',
      );
      expect(m.isPaid, isTrue);
    });
  });
}
