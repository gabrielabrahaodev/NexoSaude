import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/patient_registration.dart';
import 'package:odonto_controle/models/treatment_teeth.dart';

void main() {
  test(
    'cadastro preserva endereço legado e não altera aceite ou dados clínicos',
    () {
      final source = <String, dynamic>{
        'name': 'Maria',
        'clinicId': 'c',
        'address': 'Rua Antiga, 10 - Centro',
        'lgpdPortalConsent': {'accepted': true},
        'portalToken': 'token',
        'risk': 'red',
        'emergencyContact': {'note': 'preservar'},
      };
      final draft = PatientRegistrationDraft.fromMap(source);
      draft.values['socialName'] = 'Mari';
      final patch = draft.toPatch();
      expect(patch['address'], source['address']);
      expect((patch['emergencyContact'] as Map)['note'], 'preservar');
      expect(patch.keys, isNot(contains('lgpdPortalConsent')));
      expect(patch.keys, isNot(contains('portalToken')));
      expect(patch.keys, isNot(contains('clinicId')));
      expect(patch['socialName'], 'Mari');
    },
  );
  test(
    'cadastro atualiza endereço estruturado, contato e preferências sem perder metadados',
    () {
      final draft = PatientRegistrationDraft.fromMap({
        'name': 'Maria',
        'address': {'full_address': 'Antigo', 'custom': 'preservar'},
        'addressDetails': {'source': 'legacy'},
      });
      draft.values.addAll({
        'street': 'Rua Nova',
        'number': '12',
        'neighborhood': 'Centro',
        'cityState': 'São Paulo - SP',
        'cep': '01001000',
        'emergencyName': 'José',
        'emergencyPhone': '11999990000',
        'referralSource': 'Google',
      });
      draft.reminderChannels = {'WhatsApp', 'E-mail'};
      final patch = draft.toPatch();
      expect((patch['address'] as Map)['custom'], 'preservar');
      expect((patch['addressDetails'] as Map)['city'], 'São Paulo');
      expect((patch['addressDetails'] as Map)['state'], 'SP');
      expect((patch['emergencyContact'] as Map)['name'], 'José');
      expect(
        (patch['contactPreferences'] as Map)['reminderChannels'],
        containsAll(['WhatsApp', 'E-mail']),
      );
    },
  );
  test(
    'documentos: CPF só recebe indicador válido com dígitos verificadores corretos',
    () {
      expect(PatientRegistrationDraft.validCpf('529.982.247-25'), isTrue);
      expect(PatientRegistrationDraft.validCpf('123.123.123-12'), isFalse);
      expect(PatientRegistrationDraft.validCpf('11111111111'), isFalse);
      expect(PatientRegistrationDraft.validCpf(''), isFalse);
    },
  );
  test(
    'dentes vinculados vêm de referências explícitas e não do nome do procedimento',
    () {
      expect(
        treatmentLinkedTeeth({
          'items': [
            {'name': 'Restauração dente 22'},
          ],
        }),
        isEmpty,
      );
      expect(
        treatmentLinkedTeeth({
          'teeth': [22, 22, 99, 19],
          'items': [
            {'toothId': '36'},
            {
              'dentes': [
                11,
                {'id': 48},
              ],
            },
          ],
        }),
        [11, 22, 36, 48],
      );
    },
  );
}
