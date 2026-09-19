import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/therapeutic_status.dart';

void main() {
  group('TherapeuticStatus', () {
    test('rótulos em palavras do usuário', () {
      expect(TherapeuticStatus.lead.label, 'Prospecto');
      expect(TherapeuticStatus.active.label, 'Acompanhamento');
      expect(TherapeuticStatus.discharged.label, 'Alta-Manutenção');
    });

    test('valor gravado mantém o enum em inglês', () {
      expect(TherapeuticStatus.lead.storage, 'lead');
      expect(TherapeuticStatus.active.storage, 'active');
      expect(TherapeuticStatus.discharged.storage, 'discharged');
    });

    test('parse com fallback prospecto', () {
      expect(parseTherapeuticStatus('lead'), TherapeuticStatus.lead);
      expect(parseTherapeuticStatus('active'), TherapeuticStatus.active);
      expect(parseTherapeuticStatus('discharged'),
          TherapeuticStatus.discharged);
      expect(parseTherapeuticStatus(null), TherapeuticStatus.lead);
      expect(parseTherapeuticStatus('Ativo'), TherapeuticStatus.lead);
      expect(parseTherapeuticStatus('lixo'), TherapeuticStatus.lead);
    });
  });
}
