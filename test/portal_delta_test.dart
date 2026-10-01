import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/portal_mirror.dart';

void main() {
  group('applySessionUpsert', () {
    test('adiciona em lista vazia', () {
      final out = applySessionUpsert([], {'id': 'a', 'status': 'X'});
      expect(out.length, 1);
      expect(out.first['id'], 'a');
    });

    test('atualiza pelo mesmo id sem duplicar', () {
      final out = applySessionUpsert(
        [
          {'id': 'a', 'status': 'X'}
        ],
        {'id': 'a', 'status': 'Y'},
      );
      expect(out.length, 1);
      expect(out.first['status'], 'Y');
    });
  });

  group('applySessionRemove', () {
    test('remove pelo id e mantem as demais', () {
      final out = applySessionRemove(
        [
          {'id': 'a'},
          {'id': 'b'}
        ],
        'a',
      );
      expect(out.map((e) => e['id']), ['b']);
    });
  });

  group('needsFullRebuild', () {
    test('com token e sem doc pede rebuild', () {
      expect(
          PortalMirrorSync.needsFullRebuild(
              token: 'tok', patched: false),
          isTrue);
    });

    test('com token e doc aplicado nao pede rebuild', () {
      expect(
          PortalMirrorSync.needsFullRebuild(
              token: 'tok', patched: true),
          isFalse);
    });

    test('sem token nunca pede rebuild (LGPD)', () {
      expect(
          PortalMirrorSync.needsFullRebuild(
              token: null, patched: false),
          isFalse);
      expect(
          PortalMirrorSync.needsFullRebuild(
              token: '', patched: false),
          isFalse);
    });
  });
}
