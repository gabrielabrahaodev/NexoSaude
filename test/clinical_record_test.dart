import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/clinical_record_service.dart';

void main() {
  group('whatsappChargeRecord', () {
    test('leva texto exato, operador e data', () {
      final m = ClinicalRecordService.whatsappChargeRecord(
        clinicId: 'c1',
        patientId: 'p1',
        patientName: 'Gabriel',
        message: 'Lembrete de R\$ 100',
        operatorName: 'Léo',
        at: DateTime(2026, 9, 29, 10, 5),
      );
      expect(m['procedureName'], 'Cobrança via WhatsApp');
      expect((m['description'] as String).contains('Lembrete de R\$ 100'),
          isTrue);
      expect((m['description'] as String).contains('Léo'), isTrue);
      expect((m['description'] as String).contains('29/09/2026 10:05'),
          isTrue);
      expect(m['patientId'], 'p1');
    });
  });
}
