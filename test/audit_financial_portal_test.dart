import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/financial_service.dart';
import 'package:odonto_controle/services/portal_mirror.dart';
import 'package:odonto_controle/services/session_manager.dart';
import 'support/memory_firestore.dart';

void main() {
  late MemoryFirestore db;
  setUp(() {
    db = MemoryFirestore();
    SessionManager().setClinic('a', 'Clínica A', 'dental');
  });
  tearDown(() => SessionManager().clear());
  void seedPayment() {
    db.docs.addAll({
      'financial/parent': {
        'clinicId': 'a',
        'amount': 60.0,
        'paidAmount': 0.0,
        'status': 'pendente',
      },
      'financial/child': {
        'clinicId': 'a',
        'parentId': 'parent',
        'amount': 40.0,
        'status': 'pago',
      },
      'financial/foreign': {
        'clinicId': 'b',
        'parentId': 'parent',
        'amount': 500.0,
      },
      'expenses/commission': {'clinicId': 'a', 'relatedFinancialId': 'parent'},
      'expenses/childFee': {'clinicId': 'a', 'relatedFinancialId': 'child'},
      'expenses/lab': {
        'clinicId': 'a',
        'relatedFinancialId': 'parent',
        'source': 'lab_order',
      },
      'expenses/foreign': {'clinicId': 'b', 'relatedFinancialId': 'parent'},
    });
  }

  test(
    'estorno restaura saldo e remove só recebimentos/custos da clínica',
    () async {
      seedPayment();
      await FinancialService(firestore: db).voidPayment('parent');
      expect(db.docs['financial/parent']!['amount'], 100.0);
      expect(db.docs['financial/parent']!['status'], 'pendente');
      expect(db.docs.containsKey('financial/child'), isFalse);
      expect(db.docs.containsKey('expenses/commission'), isFalse);
      expect(db.docs.containsKey('expenses/childFee'), isFalse);
      for (final path in [
        'financial/foreign',
        'expenses/lab',
        'expenses/foreign',
      ]) {
        expect(db.docs.containsKey(path), isTrue, reason: path);
      }
      expect(db.queries.every((q) => q.filters['clinicId'] == 'a'), isTrue);
    },
  );
  for (final failure in ['query', 'commit']) {
    test('falha de $failure preserva receita, filhas e despesas', () async {
      seedPayment();
      final before = {for (final e in db.docs.entries) e.key: Map.of(e.value)};
      if (failure == 'query') {
        db.failQuery = 'expenses';
      } else {
        db.failCommit = true;
      }
      await expectLater(
        FinancialService(firestore: db).voidPayment('parent'),
        throwsStateError,
      );
      expect(db.docs, before);
    });
  }
  test('estorno rejeita lançamento fora da clínica atual', () async {
    seedPayment();
    SessionManager().setClinic('b', 'Clínica B', 'dental');
    await expectLater(
      FinancialService(firestore: db).voidPayment('parent'),
      throwsStateError,
    );
    expect(db.docs.containsKey('expenses/commission'), isTrue);
  });

  test(
    'portal repõe quarta dívida, recalcula saldo e preserva pedidos',
    () async {
      db.docs['patients/p'] = {'clinicId': 'a', 'portalToken': 'token'};
      db.docs['portal/token'] = {
        'pedidoRemarcacao': {'test': true},
        'sessions': ['keep'],
      };
      for (var i = 1; i <= 4; i++) {
        db.docs['financial/d$i'] = {
          'clinicId': 'a',
          'patientId': 'p',
          'amount': i * 100.0,
          'paidAmount': 0.0,
          'status': 'pendente',
          'dueDate': Timestamp.fromDate(DateTime(2026, 11, i)),
        };
      }
      db.docs['financial/other'] = {
        'clinicId': 'b',
        'patientId': 'p',
        'amount': 999.0,
        'dueDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
      };
      await syncPortalDebts(db, 'p');
      expect(db.docs['portal/token']!['debtsTotal'], 1000.0);
      db.docs['financial/d1']!.addAll({'status': 'pago', 'paidAmount': 100.0});
      db.docs['financial/d2']!['paidAmount'] = 50.0;
      await syncPortalDebts(db, 'p');
      final mirror = db.docs['portal/token']!;
      expect(mirror['debtsTotal'], 850.0);
      expect(mirror['debtsCount'], 3);
      expect((mirror['debts'] as List).map((d) => d['id']), ['d2', 'd3', 'd4']);
      expect(mirror['pedidoRemarcacao'], {'test': true});
      expect(mirror['sessions'], ['keep']);
      for (var i = 2; i <= 4; i++) {
        db.docs['financial/d$i']!['status'] = 'cancelado';
      }
      await syncPortalDebts(db, 'p');
      expect(db.docs['portal/token']!['debtsTotal'], 0.0);
      expect(db.docs['portal/token']!['debtsCount'], 0);
      expect(db.docs['portal/token']!['debts'], isEmpty);
    },
  );
  test(
    'token revogado e paciente sem portal não recebem atualizações',
    () async {
      db.docs['patients/p'] = {'clinicId': 'a', 'portalToken': 'new'};
      await syncPortalDebts(db, 'p', token: 'old');
      expect(db.docs.keys.where((k) => k.startsWith('portal/')), isEmpty);
      db.docs['patients/p']!['portalToken'] = '';
      await syncPortalDebts(db, 'p');
      expect(db.queries, isEmpty);
    },
  );
  test('status quitado legado não reaparece como dívida sem paidAmount', () {
    expect(buildPortalDebts([
      for (final status in ['pago', 'paid', 'quitado', 'anticipated'])
        {'id': status, 'amount': 100.0, 'status': status,
         'dueDate': DateTime(2026, 11, 1)},
    ]), {'debts': [], 'debtsTotal': 0.0, 'debtsCount': 0,
         'debtsTruncated': false});
  });
  test('espelho ausente exige rebuild completo sem criar documento parcial', () async {
    db.docs['patients/p'] = {'clinicId': 'a', 'portalToken': 'token'};
    expect(await syncPortalDebts(db, 'p'), isFalse);
    expect(db.docs.containsKey('portal/token'), isFalse);
    expect(db.queries, isEmpty);
  });
}
