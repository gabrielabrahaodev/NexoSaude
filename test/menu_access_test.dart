import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/menu_access.dart';

void main() {
  group('MenuAccess.canShow', () {
    test('owner vê tudo, menos Master (só superadmin)', () {
      final access = {for (final k in MenuAccess.keys) k: false};
      for (final k in MenuAccess.keys) {
        expect(
          MenuAccess.canShow(
              isOwner: true, role: 'owner', menuKey: k, access: access),
          k == 'master' ? isFalse : isTrue,
          reason: k,
        );
      }
    });

    test('sem mapa, defaults espelham os cadeados antigos', () {
      const operacionais = [
        'dashboard',
        'agenda',
        'atendimento',
        'pacientes',
        'laboratorio',
        'financeiro',
        'relatorios',
        'noticias',
        'cobrancas',
        'fluxo',
      ];
      for (final k in operacionais) {
        expect(
          MenuAccess.canShow(isOwner: false, role: 'dentista', menuKey: k),
          isTrue,
          reason: k,
        );
      }
      // Gestão: recepção via (como hoje), dentista não.
      expect(
        MenuAccess.canShow(
            isOwner: false, role: 'recepcionista', menuKey: 'gestao'),
        isTrue,
      );
      expect(
        MenuAccess.canShow(
            isOwner: false, role: 'dentista', menuKey: 'gestao'),
        isFalse,
      );
      // Sensíveis: ninguém sem cargo.
      for (final k in ['clinicas', 'funcionarios', 'master']) {
        expect(
          MenuAccess.canShow(
              isOwner: false, role: 'recepcionista', menuKey: k),
          isFalse,
          reason: k,
        );
      }
      // Master: só superadmin.
      expect(
        MenuAccess.canShow(
            isOwner: false, role: 'superadmin', menuKey: 'master'),
        isTrue,
      );
    });

    test('mapa explícito vence o default (dentista liberável)', () {
      expect(
        MenuAccess.canShow(
            isOwner: false,
            role: 'dentista',
            menuKey: 'gestao',
            access: {'gestao': true}),
        isTrue,
      );
      expect(
        MenuAccess.canShow(
            isOwner: false,
            role: 'recepcionista',
            menuKey: 'gestao',
            access: {'gestao': false}),
        isFalse,
      );
      // Master com opt-out.
      expect(
        MenuAccess.canShow(
            isOwner: false,
            role: 'superadmin',
            menuKey: 'master',
            access: {'master': false}),
        isFalse,
      );
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

    test('14 chaves cobrem todos os índices do menu (inclui master)', () {
      expect(MenuAccess.indexKey.length, 14);
      for (var i = 0; i < 14; i++) {
        expect(MenuAccess.indexKey.containsKey(i), isTrue, reason: 'índice $i');
      }
      expect(MenuAccess.keys.toSet().length, 14);
      expect(MenuAccess.keyIndex['atendimento'], 12);
      expect(MenuAccess.keyIndex['master'], 13);
    });

    test('psico esconde laboratorio; dental esconde fluxo; atendimento/master nos dois', () {
      final psy = MenuAccess.keysForClinicType('psychology');
      expect(psy.contains('laboratorio'), isFalse);
      expect(psy.contains('fluxo'), isTrue);
      expect(psy.contains('atendimento'), isTrue);
      expect(psy.contains('master'), isTrue);
      expect(psy.length, 13);

      final dental = MenuAccess.keysForClinicType('dental');
      expect(dental.contains('fluxo'), isFalse);
      expect(dental.contains('laboratorio'), isTrue);
      expect(dental.contains('atendimento'), isTrue);
      expect(dental.contains('master'), isTrue);
      expect(dental.length, 13);
    });

    test('tipo desconhecido cai em dental', () {
      expect(MenuAccess.keysForClinicType('fisio'), MenuAccess.keysForClinicType('dental'));
      expect(MenuAccess.keysForClinicType(null), MenuAccess.keysForClinicType('dental'));
    });
  });

  group('MenuAccess sub-chaves da Gestão', () {
    test('abas visíveis por padrão; seções sensíveis só owner', () {
      for (final k in MenuAccess.gestaoTabKeys) {
        expect(
          MenuAccess.canShow(isOwner: false, role: 'dentista', menuKey: k),
          isTrue,
          reason: k,
        );
      }
      for (final k in MenuAccess.gestaoSectionKeys) {
        expect(
          MenuAccess.canShow(isOwner: false, role: 'dentista', menuKey: k),
          isFalse,
          reason: k,
        );
        expect(
          MenuAccess.canShow(isOwner: false, role: 'recepcionista', menuKey: k),
          isFalse,
          reason: k,
        );
      }
    });

    test('mapa libera seção e esconde aba', () {
      expect(
        MenuAccess.canShow(
            isOwner: false,
            role: 'dentista',
            menuKey: 'g_pix',
            access: {'g_pix': true}),
        isTrue,
      );
      expect(
        MenuAccess.canShow(
            isOwner: false,
            role: 'recepcionista',
            menuKey: 'g_estoque',
            access: {'g_estoque': false}),
        isFalse,
      );
    });

    test('9 sub-chaves com rótulo', () {
      final all = [
        ...MenuAccess.gestaoTabKeys,
        ...MenuAccess.gestaoSectionKeys
      ];
      expect(all.length, 9);
      for (final k in all) {
        expect(MenuAccess.labels[k]?.isNotEmpty, isTrue, reason: k);
      }
    });
  });
}
