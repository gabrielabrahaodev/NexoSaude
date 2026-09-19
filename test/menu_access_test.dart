import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/menu_access.dart';

void main() {
  group('MenuAccess.canShow', () {
    test('owner vê tudo mesmo com mapa restritivo', () {
      final access = {for (final k in MenuAccess.keys) k: false};
      for (final k in MenuAccess.keys) {
        expect(
          MenuAccess.canShow(isOwner: true, menuKey: k, access: access),
          isTrue,
          reason: k,
        );
      }
    });

    test('sem mapa, tudo visível (default)', () {
      for (final k in MenuAccess.keys) {
        expect(
          MenuAccess.canShow(isOwner: false, menuKey: k, access: null),
          isTrue,
          reason: k,
        );
      }
    });

    test('chave ausente no mapa = visível', () {
      expect(
        MenuAccess.canShow(
            isOwner: false, menuKey: 'agenda', access: {'agenda': true}),
        isTrue,
      );
      expect(
        MenuAccess.canShow(
            isOwner: false, menuKey: 'financeiro', access: {'agenda': true}),
        isTrue,
      );
    });

    test('false esconde só aquela chave', () {
      final access = {'financeiro': false, 'relatorios': false};
      expect(
        MenuAccess.canShow(
            isOwner: false, menuKey: 'financeiro', access: access),
        isFalse,
      );
      expect(
        MenuAccess.canShow(
            isOwner: false, menuKey: 'relatorios', access: access),
        isFalse,
      );
      expect(
        MenuAccess.canShow(
            isOwner: false, menuKey: 'agenda', access: access),
        isTrue,
      );
    });

    test('13 chaves cobrem todos os índices do menu (inclui atendimento)', () {
      expect(MenuAccess.indexKey.length, 13);
      for (var i = 0; i < 13; i++) {
        expect(MenuAccess.indexKey.containsKey(i), isTrue, reason: 'índice $i');
      }
      expect(MenuAccess.keys.toSet().length, 13);
      expect(MenuAccess.keyIndex['atendimento'], 12);
    });

    test('psico esconde laboratorio; dental esconde fluxo; atendimento nos dois', () {
      final psy = MenuAccess.keysForClinicType('psychology');
      expect(psy.contains('laboratorio'), isFalse);
      expect(psy.contains('fluxo'), isTrue);
      expect(psy.contains('atendimento'), isTrue);
      expect(psy.length, 12);

      final dental = MenuAccess.keysForClinicType('dental');
      expect(dental.contains('fluxo'), isFalse);
      expect(dental.contains('laboratorio'), isTrue);
      expect(dental.contains('atendimento'), isTrue);
      expect(dental.length, 12);
    });

    test('tipo desconhecido cai em dental', () {
      expect(MenuAccess.keysForClinicType('fisio'), MenuAccess.keysForClinicType('dental'));
      expect(MenuAccess.keysForClinicType(null), MenuAccess.keysForClinicType('dental'));
    });
  });
}
