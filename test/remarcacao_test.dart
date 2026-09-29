import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/remarcacao_service.dart';

void main() {
  group('refuseText', () {
    test('traz nome, data proposta e link novo', () {
      final msg = refuseText(
        patientName: 'Gabriel',
        proposed: DateTime(2026, 9, 20, 9, 0),
        portalUrl: 'https://nexosaude.web.app/sistema-interno/portal.html?t=ABC',
      );
      expect(msg.contains('Gabriel'), isTrue);
      expect(msg.contains('20/09'), isTrue);
      expect(msg.contains('09:00'), isTrue);
      expect(msg.contains('https://'), isTrue);
    });
  });

  group('confirmText', () {
    test('traz nome, data, hora e link do portal', () {
      final msg = confirmText(
        patientName: 'Gabriel',
        confirmed: DateTime(2026, 9, 22, 14, 30),
        portalUrl: 'https://nexosaude.web.app/sistema-interno/portal.html?t=ABC',
      );
      expect(msg.contains('Gabriel'), isTrue);
      expect(msg.contains('22/09'), isTrue);
      expect(msg.contains('14:30'), isTrue);
      expect(msg.contains('reagendamento'), isTrue);
      expect(msg.contains('https://'), isTrue);
    });
  });
}
