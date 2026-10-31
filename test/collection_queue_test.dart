import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odonto_controle/models/collection_queue.dart';
import 'package:odonto_controle/services/collection_queue_service.dart';
import 'package:odonto_controle/services/oracle_report_service.dart';
import 'package:odonto_controle/utils/collection_export.dart';

const dental = CollectionClinic(
  'd',
  'Jabaquara',
  'dental',
  pixKey: 'teste@pix.com',
  city: 'São Paulo',
);
const psycho = CollectionClinic('p', 'Yervant', 'psychology');
final now = DateTime(2026, 10, 31, 12);
ReportDocument fin(
  String id, {
  String clinic = 'd',
  String patient = 'a',
  double amount = 300,
  double paid = 0,
  String status = 'pending',
  String? period,
  String? plan,
  Map<String, dynamic> extra = const {},
}) => ReportDocument(id, {
  'clinicId': clinic,
  'patientId': patient,
  'patientName': 'Ana',
  'amount': amount,
  'paidAmount': paid,
  'status': status,
  'type': 'income',
  'title': 'Procedimento',
  'date': Timestamp.fromDate(DateTime(2026, 10, 1)),
  'dueDate': Timestamp.fromDate(DateTime(2026, 10, 6)),
  if (period != null) 'monthlyPeriod': period,
  if (plan != null) 'planId': plan,
  ...extra,
});
ReportDocument person(String clinic, [String id = 'a']) => ReportDocument(id, {
  'clinicId': clinic,
  'name': 'Ana',
  'phone': '11988887777',
  'recordNumber': '4819',
});
ReportDocument session(
  String id, {
  String plan = 'plan',
  String status = 'Finalizado',
  String presence = 'Attended',
  bool certificate = false,
  int month = 10,
}) => ReportDocument(id, {
  'clinicId': 'p',
  'patientId': 'a',
  'planId': plan,
  'status': status,
  'attendanceStatus': presence,
  'hasMedicalCertificate': certificate,
  'date': Timestamp.fromDate(DateTime(2026, month, 3)),
});
CollectionQueue queue(
  List<ReportDocument> docs, {
  List<ReportDocument>? sessions,
  List<ReportDocument>? people,
  List<ReportDocument>? plans,
  List<CollectionClinic>? clinics,
}) => CollectionQueue.build(
  clinics: clinics ?? [dental, psycho],
  month: now,
  now: now,
  financial: docs,
  patients: people ?? [person('d'), person('p')],
  appointments: sessions ?? [],
  plans:
      plans ??
      [
        const ReportDocument('plan', {
          'clinicId': 'p',
          'thirdPartyDiscount': 80,
        }),
      ],
);
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  test(
    'direct outstanding balances dedupe, exclude terminal/expenses/outside month/unapproved clinics',
    () {
      final a = fin('a', paid: 100);
      final q = queue([
        a,
        a,
        fin('paid', status: 'Pago'),
        fin('flag', extra: {'isPaid': true}),
        fin('cancel', status: 'Cancelado'),
        fin('old', status: 'substituido'),
        fin('paidValue', paid: 300),
        fin('expense', extra: {'type': 'expense'}),
        fin('other', clinic: 'unauthorized'),
        fin(
          'nov',
          extra: {'dueDate': Timestamp.fromDate(DateTime(2026, 11, 1))},
        ),
      ]);
      expect(q.charges.map((c) => c.key), ['single:a']);
      expect(q.pending, 200);
      expect(q.patients, 1);
    },
  );
  test(
    'psychology rateio planned divisor, discount before prorating, certificate excluded, partial month',
    () {
      final q = queue(
        [
          fin(
            'package',
            clinic: 'p',
            amount: 480,
            period: '2026-10',
            plan: 'plan',
          ),
        ],
        sessions: [
          session('1'),
          session('2', presence: 'Missed', certificate: true),
          session('3', presence: 'Missed'),
          session('4', status: 'Agendado'),
          session('cancel', status: 'Cancelado'),
          session('sept', month: 9),
          session('other', plan: 'another'),
        ],
      );
      final c = q.charges.single;
      expect(c.amount, 200);
      expect(c.bill!.previstas, 4);
      expect(c.bill!.isPartial, true);
      expect(c.bill!.missedExcused, 1);
    },
  );
  test(
    'packages use competence, singles use due month; no double inclusion',
    () {
      final q = queue(
        [
          fin(
            'package',
            clinic: 'p',
            period: '2026-10',
            plan: 'plan',
            extra: {'dueDate': Timestamp.fromDate(DateTime(2026, 11, 10))},
          ),
          fin('oldPackage', clinic: 'p', period: '2026-09', plan: 'plan'),
          fin(
            'single',
            clinic: 'p',
            extra: {'billingKind': 'session', 'monthlyPeriod': '2026-09'},
          ),
        ],
        sessions: [session('1')],
      );
      expect(q.charges.length, 2);
      expect(q.charges.where((c) => c.isPackage).length, 1);
    },
  );
  test('same patient and period never merges different plans or clinics', () {
    final q = queue(
      [
        fin('p1', clinic: 'p', period: '2026-10', plan: 'plan'),
        fin('p2', clinic: 'p', period: '2026-10', plan: 'other'),
        fin('d'),
      ],
      sessions: [
        session('1'),
        session('2', plan: 'other'),
      ],
      plans: [
        const ReportDocument('plan', {'clinicId': 'p'}),
        const ReportDocument('other', {'clinicId': 'p'}),
      ],
    );
    expect(q.charges.length, 3);
    expect(q.patients, 2);
    expect(q.only('d').charges.length, 1);
  });
  test(
    'missing or ambiguous package links block charging and are excluded from calculated KPI',
    () {
      final missing = queue([
        fin('package', clinic: 'p', period: '2026-10', plan: 'plan'),
      ]);
      expect(missing.charges.single.issue, isNotNull);
      expect(missing.pending, 0);
      expect(missing.charges.single.canContact(now), false);
      final ambiguous = queue(
        [fin('legacy', clinic: 'p', period: '2026-10')],
        sessions: [session('1')],
      );
      expect(ambiguous.charges.single.issue, isNotNull);
    },
  );
  test(
    'paid, partially paid or quoted packages freeze rather than recalculate',
    () {
      final q = queue([
        fin(
          'package',
          clinic: 'p',
          period: '2026-10',
          plan: 'plan',
          status: 'cobrado',
          amount: 120,
          extra: {'billingRatedAmount': 120},
        ),
      ]);
      expect(q.charges.single.amount, 120);
      expect(q.charges.single.bill, isNull);
      final p = queue([
        fin('package', clinic: 'p', period: '2026-10', plan: 'plan', paid: 50),
      ]);
      expect(p.charges.single.amount, 250);
      expect(p.charges.single.bill, isNull);
    },
  );
  test(
    'contact history dedup event across grouped docs; confirmed is not paid',
    () {
      final event = {
        'eventId': 'e',
        'method': 'whatsapp_manual',
        'date': '2026-10-20T12:00:00',
      };
      final q = queue([
        fin(
          'one',
          extra: {
            'contactHistory': [
              event,
              {'method': 'manual_reschedule', 'date': '2026-10-21'},
            ],
          },
        ),
        fin(
          'two',
          extra: {
            'contactHistory': [event],
          },
        ),
      ]);
      expect(q.contacts, 1);
      expect(q.settled, 0);
      expect(q.pending, 600);
      expect(q.only('d').contacts, 1);
    },
  );
  test(
    'cash KPI uses same effective month as reports, not due date; unit filters isolate totals',
    () {
      final q = queue([
        fin(
          'paid',
          status: 'paid',
          extra: {
            'paidDate': Timestamp.fromDate(DateTime(2026, 10, 5)),
            'dueDate': Timestamp.fromDate(DateTime(2026, 9, 5)),
          },
        ),
        fin('other', clinic: 'p', status: 'paid', amount: 100),
        fin('cancel', status: 'Cancelado'),
      ]);
      expect(q.settled, 400);
      expect(q.settledCount, 2);
      expect(q.only('d').settled, 300);
      expect(q.only('d').only('d').settled, 300);
      expect(q.only('p').settled, 100);
    },
  );
  test(
    'delay and today contact suppress batch eligibility; search handles accents, record and invoice',
    () {
      final delayed = queue([
        fin(
          'debt',
          extra: {'nextContactAt': Timestamp.fromDate(DateTime(2026, 11, 2))},
        ),
      ]).charges.single;
      expect(delayed.canContact(now), false);
      expect(delayed.matches('4819'), true);
      expect(delayed.matches('debt'), true);
      final contacted = queue([
        fin('c', extra: {'lastContactDate': Timestamp.fromDate(now)}),
      ]).charges.single;
      expect(contacted.canContact(now), false);
    },
  );
  test(
    'message is deterministic, includes actual value/unit and valid Pix payload or key fallback',
    () {
      final c = queue([fin('a', paid: 100)]).charges.single;
      expect(c.message(now), c.message(now));
      expect(c.message(now), contains('Jabaquara'));
      expect(c.message(now), contains('200,00'));
      expect(c.message(now), contains('br.gov.bcb.pix'));
      final noPix = queue([fin('a', clinic: 'p')]).charges.single;
      expect(noPix.message(now), isNot(contains('Pix')));
      final keyOnly = queue(
        [fin('a')],
        clinics: [
          const CollectionClinic('d', 'Jabaquara', 'dental', pixKey: 'key'),
        ],
      ).charges.single;
      expect(keyOnly.message(now), contains('Chave Pix: key'));
    },
  );
  test(
    'write guard rejects cross-clinic, paid, canceled, stale and deleted records',
    () {
      final doc = fin('a');
      final c = queue([doc]).charges.single;
      expect(
        () => validateCollectionWrite(c, doc.data, doc.data),
        returnsNormally,
      );
      for (final patch in [
        {'clinicId': 'p'},
        {'patientId': 'other'},
        {'status': 'paid'},
        {'status': 'Cancelado'},
        {'paidAmount': 25},
        {'amount': 350},
        {'nextContactAt': Timestamp.fromDate(now)},
      ]) {
        expect(
          () => validateCollectionWrite(c, doc.data, {...doc.data, ...patch}),
          throwsStateError,
        );
      }
      expect(
        () => validateCollectionWrite(c, doc.data, null),
        throwsStateError,
      );
    },
  );
  test(
    'quote allocation rounds once and conserves cents across package lines',
    () {
      final docs = [
        fin('one', clinic: 'p', period: '2026-10', plan: 'plan', amount: 1),
        fin('two', clinic: 'p', period: '2026-10', plan: 'plan', amount: 1),
        fin('three', clinic: 'p', period: '2026-10', plan: 'plan', amount: 1),
      ];
      final c = CollectionCharge(
        key: 'k',
        clinic: psycho,
        patientId: 'a',
        patientName: 'Ana',
        description: 'Pacote',
        documents: docs,
        amount: 1,
      );
      final shares = [for (final d in docs) collectionQuoteShare(c, d.data)];
      expect(shares, [.33, .33, .34]);
    },
  );
  test(
    'apuração preserves original, writes no payment, conserves cents and never discounts twice',
    () {
      final doc = fin(
        'pkg',
        clinic: 'p',
        amount: 480,
        period: '2026-10',
        plan: 'plan',
      );
      final c = queue(
        [doc],
        sessions: [
          session('one'),
          session('two', status: 'Agendado'),
        ],
      ).charges.single;
      expect(c.amount, 200);
      final patch = collectionApurationPatch(c, doc.data, now);
      expect(patch['amount'], 200);
      expect(patch['billingOriginalAmount'], 480);
      expect(patch.containsKey('paidAmount'), false);
      expect(patch.containsKey('isPaid'), false);
      expect(patch.containsKey('paymentDate'), false);
      final rated = ReportDocument(doc.id, {...doc.data, ...patch});
      final next = queue([rated], sessions: [session('one'), session('two')]);
      expect(next.charges.single.amount, 200);
      expect(next.charges.single.bill, isNull);
      expect(
        () => collectionApurationPatch(c, rated.data, now),
        throwsStateError,
      );
    },
  );
  test('missing patient blocks contact even when debt exists', () {
    final c = queue([fin('a')], people: []).charges.single;
    expect(c.issue, isNotNull);
    expect(c.canContact(now), false);
  });
  test(
    'phone normalization supports Brazilian DDD 55 and missing phone blocks dispatch',
    () {
      expect(collectionPhone('(55) 99999-1234'), '5555999991234');
      expect(collectionPhone('+55 11 98888-1111'), '5511988881111');
      expect(collectionPhone('123'), '');
      final c = queue(
        [fin('a')],
        people: [
          const ReportDocument('a', {'clinicId': 'd', 'name': 'Ana'}),
        ],
      ).charges.single;
      expect(c.canContact(now), false);
    },
  );
  test(
    'apuração source guard rejects changed presence, discount, clinic or removed source',
    () {
      final original = session('1').data;
      expect(
        () => validateCollectionSource(original, original, plan: false),
        returnsNormally,
      );
      for (final patch in [
        {'status': 'Agendado'},
        {'hasMedicalCertificate': true},
        {'clinicId': 'd'},
        {'planId': 'other'},
      ]) {
        expect(
          () => validateCollectionSource(original, {
            ...original,
            ...patch,
          }, plan: false),
          throwsStateError,
        );
      }
      expect(
        () => validateCollectionSource(original, null, plan: false),
        throwsStateError,
      );
      expect(
        () => validateCollectionSource(
          {'thirdPartyDiscount': 80},
          {'thirdPartyDiscount': 90},
          plan: true,
        ),
        throwsStateError,
      );
    },
  );
  test('CSV escapes formulas, includes real pending/paid, no portal token', () {
    final q = queue(
      [fin('a')],
      people: [
        const ReportDocument('a', {
          'clinicId': 'd',
          'name': '=Ana;"Teste"',
          'portalToken': 'SECRET',
        }),
      ],
    );
    final csv = collectionCsv(now, q.charges, q);
    expect(csv, contains("'=Ana;\"\"Teste\"\""));
    expect(csv, isNot(contains('SECRET')));
    expect(csv, contains('300,00'));
  });
}
