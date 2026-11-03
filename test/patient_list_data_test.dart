import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/patient_list_entry.dart';
import 'package:odonto_controle/services/oracle_report_service.dart';
import 'package:odonto_controle/utils/patient_list_export.dart';

void main() {
  final now = DateTime(2026, 10, 31, 12);
  final rows = [
    PatientListEntry('b', {
      'name': 'Bruna',
      'phone': '(12) 31123-1231',
      'cpf': '123.123.123-12',
      'recordNumber': '4819',
      'status': 'Ativo',
      'createdAt': DateTime(2026, 10, 1),
      'lgpdPortalConsent': {'accepted': true},
    }),
    PatientListEntry('a', {
      'name': 'Álvaro',
      'phone': '',
      'cpf': '',
      'status': 'Ativo',
      'createdAt': DateTime(2026, 10, 20),
    }),
    PatientListEntry('c', {'name': 'Carlos', 'status': 'Inativo'}),
  ];
  final ctx = PatientListContext(
    debts: {'b': 600},
    treatments: {'b'},
    budgets: {'a', 'b'},
    attendance: {
      'b': {'date': now},
    },
  );
  test('name accents, CPF/phone punctuation and registered record search', () {
    expect(rows[1].matches('alvaro'), true);
    expect(rows[0].matches('12311231231'), true);
    expect(rows[0].matches('12312312312'), true);
    expect(rows[0].matches('4819'), true);
    expect(rows[0].matches('inexistente'), false);
  });
  test('filters intersect; consent is not inferred from other fields', () {
    expect(
      filterPatientList(
        rows,
        context: ctx,
        filters: {PatientListFilter.noConsent},
      ).map((p) => p.id),
      ['a', 'c'],
    );
    expect(
      filterPatientList(
        rows,
        context: ctx,
        filters: {
          PatientListFilter.budget,
          PatientListFilter.debt,
          PatientListFilter.treatment,
        },
      ).map((p) => p.id),
      ['b'],
    );
    expect(
      filterPatientList(
        rows,
        context: ctx,
        filters: {PatientListFilter.noConsent, PatientListFilter.debt},
      ),
      isEmpty,
    );
  });
  test('sort alphabetical, recent, attendance; unknown dates are last', () {
    expect(filterPatientList(rows, context: ctx).map((p) => p.id), [
      'a',
      'b',
      'c',
    ]);
    expect(
      filterPatientList(
        rows,
        context: ctx,
        sort: PatientListSort.recent,
      ).map((p) => p.id),
      ['a', 'b', 'c'],
    );
    expect(
      filterPatientList(
        rows,
        context: ctx,
        sort: PatientListSort.attendance,
      ).first.id,
      'b',
    );
  });
  test('does not invent record numbers, CPF or active status', () {
    expect(rows[1].record, isEmpty);
    expect(rows[2].active, false);
    expect(patientMaskedCpf('123.123.123-12'), '123.***.***-12');
    expect(patientMaskedCpf('abc'), 'Não informado');
  });
  test(
    'unpaid amounts deduplicated, paid/cancelled/replaced/expenses excluded',
    () {
      ReportDocument d(String id, Map<String, dynamic> extra) =>
          ReportDocument(id, {
            'patientId': 'p',
            'type': 'income',
            'amount': 300,
            'paidAmount': 0,
            'status': 'pendente',
            ...extra,
          });
      final a = d('a', {'paidAmount': 50});
      final c = PatientListContext.fromDocuments(
        financial: [
          a,
          a,
          d('b', {'status': 'paid'}),
          d('c', {'status': 'cancelado'}),
          d('d', {'status': 'substituido (parcelado)'}),
          d('e', {'type': 'expense'}),
          d('f', {'isPaid': true}),
          d('g', {'paidAmount': 300}),
        ],
        plans: [],
        quotes: [],
        appointments: [],
        now: now,
      );
      expect(c.debts, {'p': 250});
    },
  );
  test(
    'active treatment and unexpired quote; only completed recent appointments',
    () {
      final c = PatientListContext.fromDocuments(
        financial: [],
        plans: [
          const ReportDocument('p', {'patientId': 'a', 'status': 'active'}),
          const ReportDocument('q', {'patientId': 'b', 'status': 'completed'}),
        ],
        quotes: [
          ReportDocument('b', {
            'patientId': 'a',
            'status': 'Pendente',
            'validUntil': now.add(const Duration(days: 1)),
          }),
          ReportDocument('old', {
            'patientId': 'b',
            'status': 'Pendente',
            'validUntil': DateTime(2020),
          }),
        ],
        appointments: [
          ReportDocument('v', {
            'patientId': 'a',
            'status': 'Finalizado',
            'date': now.subtract(const Duration(days: 1)),
            'procedure': 'Raspagem',
          }),
          ReportDocument('future', {
            'patientId': 'a',
            'status': 'Finalizado',
            'date': now.add(const Duration(days: 1)),
          }),
          ReportDocument('old', {
            'patientId': 'c',
            'status': 'Finalizado',
            'date': now.subtract(const Duration(days: 100)),
          }),
          ReportDocument('missed', {
            'patientId': 'b',
            'status': 'Faltou',
            'date': now,
          }),
        ],
        now: now,
      );
      expect(c.treatments, {'a'});
      expect(c.budgets, {'a'});
      expect(c.attendance.keys, ['a']);
      expect(c.attendance['a']!['procedure'], 'Raspagem');
    },
  );
  test(
    'CSV is UTF8 BOM ready, formula safe, preserves CPF and excludes tokens',
    () {
      final csv = patientListCsv([
        PatientListEntry('id', {
          'name': '=CMD(); "x"',
          'cpf': '01234567890',
          'portalToken': 'SECRET',
        }),
      ], null);
      expect(csv.startsWith('\uFEFF'), true);
      expect(csv, contains("'=CMD(); "));
      expect(csv, contains('""x""'));
      expect(csv, contains('01234567890'));
      expect(csv, isNot(contains('SECRET')));
      expect(csv, isNot(contains('false')));
    },
  );
}
