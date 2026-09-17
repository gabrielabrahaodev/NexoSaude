import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/financial_service.dart';

void main() {
  group('FinancialService.recordingFor', () {
    test('Pix grava como pago imediato', () {
      final r = FinancialService.recordingFor('Pix');
      expect(r.status, 'pago');
      expect(r.isPaid, isTrue);
    });

    test('Dinheiro grava como pago imediato', () {
      final r = FinancialService.recordingFor('Dinheiro');
      expect(r.status, 'pago');
      expect(r.isPaid, isTrue);
    });

    test('Débito grava como pago imediato', () {
      final r = FinancialService.recordingFor('Cartão de Débito');
      expect(r.status, 'paid');
      expect(r.isPaid, isTrue);
    });

    test('Cartão de Crédito mantém fluxo paid', () {
      final r = FinancialService.recordingFor('Cartão de Crédito');
      expect(r.status, 'paid');
      expect(r.isPaid, isTrue);
    });
  });
}
