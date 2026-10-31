import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/oracle_report_service.dart';
import 'package:odonto_controle/utils/report_export.dart';

void main() {
  final month = DateTime(2026, 10);
  ReportDocument doc(
    String id, {
    num amount = 100,
    String status = 'paid',
    String method = 'Pix',
    DateTime? date,
    DateTime? due,
    DateTime? paid,
    num partial = 0,
    String? type,
  }) => ReportDocument(id, {
    'amount': amount,
    'status': status,
    'paymentMethod': method,
    'date': date ?? month,
    'dueDate': due ?? month,
    if (paid != null) 'paidDate': paid,
    'paidAmount': partial,
    if (type != null) 'type': type,
  });
  test('deduplicates unions, but not IDs across collections', () {
    final a = doc('same');
    final s = OracleReportService.calculateMonth(
      month,
      [a, a],
      [doc('same', amount: 40)],
    );
    expect(s.transactions.length, 2);
    expect(s.totalRevenue, 100);
    expect(s.totalExpenses, 40);
    expect(s.netProfit, 60);
    expect(s.profitMargin, 60);
  });
  test('paid cash follows payment date, pending follows due date', () {
    final s = OracleReportService.calculateMonth(month, [
      doc('paid', date: DateTime(2026, 9), paid: month),
      doc('next', paid: DateTime(2026, 11)),
      doc('pending', status: 'pending', amount: 200, partial: 50),
    ], []);
    expect(s.totalRevenue, 100);
    expect(s.projectedBalance, 250);
    expect(s.transactions.map((e) => e.id), containsAll(['paid', 'pending']));
  });
  test('credit uses due month unless anticipated, debit uses paid date', () {
    final s = OracleReportService.calculateMonth(month, [
      doc('card', method: 'Cartão de Crédito', due: DateTime(2026, 11)),
      doc(
        'anticip',
        method: 'Cartão de Crédito',
        due: DateTime(2026, 12),
        paid: month,
        status: 'anticipated',
        amount: 500,
      ),
      doc(
        'debit',
        method: 'Cartão de Débito',
        due: DateTime(2026, 11),
        paid: month,
        amount: 20,
      ),
    ], []);
    expect(s.totalRevenue, 520);
    expect(s.transactions.map((e) => e.id), isNot(contains('card')));
  });
  test('cancelled, replaced and non-income do not affect result', () {
    final s = OracleReportService.calculateMonth(
      month,
      [
        doc('a', status: 'cancelled'),
        doc('b', status: 'substituido'),
        doc('c', type: 'expense'),
      ],
      [doc('x', status: 'cancelado')],
    );
    expect(s.transactions, isEmpty);
  });
  test(
    'exact month boundaries retain last microsecond and exclude neighbors',
    () {
      final before = month.subtract(const Duration(microseconds: 1));
      final next = DateTime(2026, 11);
      final last = next.subtract(const Duration(microseconds: 1));
      final s = OracleReportService.calculateMonth(month, [
        doc('before', date: before, due: before),
        doc('start'),
        doc('last', date: last, due: last),
        doc('next', date: next, due: next),
      ], []);
      expect(s.transactions.map((e) => e.id), ['start', 'last']);
    },
  );
  test('laboratory pending stays payable until paid', () {
    final expense = ReportDocument('lab', {
      'amount': '1.234,56',
      'status': 'pendente',
      'dueDate': month,
      'category': 'Laboratório',
      'supplierName': 'Lab',
      'description': 'Prótese',
    });
    final s = OracleReportService.calculateMonth(month, [], [expense]);
    expect(s.totalExpenses, 0);
    expect(s.projectedBalance, -1234.56);
    expect(reportCategory(s.transactions.single), 'Laboratório');
    expect(s.transactions.single.isPaid, false);
  });
  test('paid expenses follow actual payment month', () {
    final s = OracleReportService.calculateMonth(month, [], [
      doc('oldDue', due: DateTime(2026, 9), paid: month),
      doc('paidLater', paid: DateTime(2026, 11)),
    ]);
    expect(s.totalExpenses, 100);
    expect(s.transactions.single.id, 'oldDue');
  });
  test('missing dates are not silently assigned to today', () {
    expect(
      OracleReportService.calculateMonth(month, [
        const ReportDocument('x', {'amount': 50, 'status': 'paid'}),
      ], []).transactions,
      isEmpty,
    );
  });
  test(
    'anticipation excludes debit, cancelled, replaced, anticipated and expired',
    () {
      final today = DateTime.now();
      final future = today.add(const Duration(days: 5));
      final good = doc('c', method: 'Cartão de Crédito', due: future).data;
      expect(reportCanAnticipate(good, today), true);
      for (final changes in [
        {'paymentMethod': 'Cartão de Débito'},
        {'status': 'cancelled'},
        {'status': 'substituido'},
        {'status': 'anticipated'},
        {'dueDate': today.subtract(const Duration(days: 1))},
        {'dueDate': DateTime(today.year + 2, today.month)},
      ]) {
        expect(reportCanAnticipate({...good, ...changes}, today), false);
      }
    },
  );
  test('CSV escapes quotes and spreadsheet formulas; no invented net', () {
    final s = OracleReportService.calculateMonth(month, [
      ReportDocument('a', {
        'amount': 100,
        'status': 'paid',
        'date': month,
        'patientName': '=CMD()',
        'title': 'Coroa; "22"',
      }),
    ], []);
    final csv = reportCsv(s);
    expect(csv, contains("'=CMD()"));
    expect(csv, contains('Coroa; ""22""'));
    expect(reportNet(s.transactions.single), isNull);
  });

  test(
    'combined monthly streams wait for all sources and cancel listeners',
    () async {
      var cancelled = 0;
      final a = StreamController<QuerySnapshot>(onCancel: () => cancelled++);
      final b = StreamController<QuerySnapshot>(onCancel: () => cancelled++);
      final emitted = <List<List<QueryDocumentSnapshot>>>[];
      final sub = StreamCombiner.combineDocs([
        a.stream,
        b.stream,
      ]).listen(emitted.add);
      a.add(_QuerySnapshot());
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);
      b.add(_QuerySnapshot());
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, 1);
      await sub.cancel();
      expect(cancelled, 2);
      await a.close();
      await b.close();
    },
  );
}

class _QuerySnapshot extends Fake implements QuerySnapshot {
  @override
  List<QueryDocumentSnapshot> get docs => [];
}
