import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/portal_mirror.dart';

void main() {
  group('newPortalToken', () {
    test('32 chars URL-safe e únicos', () {
      final a = newPortalToken();
      final b = newPortalToken();
      expect(a.length, 32);
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(a), isTrue);
      expect(a == b, isFalse);
    });
  });

  group('buildPortalMirror', () {
    final now = DateTime(2026, 9, 19, 10, 0);

    test('leva próximas 3 sessões futuras ordenadas', () {
      final sessions = [
        {'id': 's1', 'date': DateTime(2026, 9, 25), 'professional': 'Léo', 'dentistId': 'd1'},
        {'id': 's2', 'date': DateTime(2026, 9, 20), 'professional': 'Léo', 'dentistId': 'd1'},
        {'id': 's0', 'date': DateTime(2026, 9, 10), 'professional': 'Léo', 'dentistId': 'd1'},
        {'id': 's3', 'date': DateTime(2026, 9, 27), 'professional': 'Léo', 'dentistId': 'd1'},
        {'id': 's4', 'date': DateTime(2026, 10, 5), 'professional': 'Léo', 'dentistId': 'd1'},
      ];
      final m = buildPortalMirror(
          clinicId: 'cid1',
          sessions: sessions, debts: [], pixKey: 'pix@clinica', now: now);
      final first = (m['sessions'] as List).first as Map;
      expect(first['dentistId'], 'd1');
      final ids =
          (m['sessions'] as List).map((s) => (s as Map)['id']).toList();
      expect(ids, ['s2', 's1', 's3']);
      expect(m['clinicId'], 'cid1');
    });

    test('sem vencimento ou futuro não aparece (só atrasos)', () {
      final debts = [
        {'id': 'd1', 'title': 'Sessão', 'amount': 300.0, 'paidAmount': 0.0},
        {'id': 'd2', 'title': 'Futuro', 'amount': 200.0, 'paidAmount': 0.0, 'dueDate': DateTime(2026, 9, 25)},
      ];
      final m = buildPortalMirror(
          clinicId: 'cid1',
          sessions: [], debts: debts, pixKey: 'pix@clinica', now: now);
      expect((m['debts'] as List), isEmpty);
      expect(m['debtsCount'], 0);
    });

    test('top 3 atrasos por vencimento + totais', () {
      final debts = [
        {'id': 'o1', 'title': 'A', 'amount': 300.0, 'paidAmount': 0.0, 'dueDate': DateTime(2026, 9, 10)},
        {'id': 'o2', 'title': 'B', 'amount': 100.0, 'paidAmount': 0.0, 'dueDate': DateTime(2026, 9, 15)},
        {'id': 'q1', 'title': 'Q', 'amount': 200.0, 'paidAmount': 200.0, 'dueDate': DateTime(2026, 9, 5)},
        {'id': 'o3', 'title': 'C', 'amount': 300.0, 'paidAmount': 0.0, 'dueDate': DateTime(2026, 9, 5)},
        {'id': 'f1', 'title': 'F', 'amount': 300.0, 'paidAmount': 0.0, 'dueDate': DateTime(2026, 9, 25)},
      ];
      final m = buildPortalMirror(
          clinicId: 'cid1',
          sessions: [], debts: debts, pixKey: '', now: now);
      final ids =
          (m['debts'] as List).map((d) => (d as Map)['id']).toList();
      expect(ids, ['o3', 'o1', 'o2']);
      expect(m['debtsTotal'], 700.0);
      expect(m['debtsCount'], 3);
    });
  });

  group('freeSlots', () {
    test('grade menos ocupados menos recusados', () {
      final free = freeSlots(
        grade: ['09:00', '09:30', '10:00'],
        busy: ['09:30'],
        refused: ['10:00'],
      );
      expect(free, ['09:00']);
    });
  });

  group('dailyGrade', () {
    test('08:30-20:00 de 30min', () {
      final g = dailyGrade();
      expect(g.first, '08:30');
      expect(g.last, '20:00');
      expect(g.length, 24);
    });

    test('parâmetros customizados', () {
      expect(
          dailyGrade(start: '09:00', end: '10:00', slot: 30),
          ['09:00', '09:30', '10:00']);
      expect(dailyGrade(start: '08:00', end: '09:00', slot: 60),
          ['08:00', '09:00']);
    });
  });
}
