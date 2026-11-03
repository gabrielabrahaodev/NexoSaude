import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import '../models/financial_model.dart';
import '../utils/display.dart' show parseBRL;

// --- MODELOS AUXILIARES ---
class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final DateTime dueDate;
  final double paidAmount;
  final bool isIncome;
  final bool isPaid;
  final String category;

  final String? patientId;
  final String paymentMethod;

  final Map<String, dynamic> details;
  double runningBalance;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.dueDate,
    this.paidAmount = 0.0,
    required this.isIncome,
    required this.isPaid,
    required this.category,
    this.patientId,
    this.paymentMethod = 'Dinheiro',
    this.runningBalance = 0.0,
    this.details = const {},
  });
}

/// Filtro da lista do Livro Caixa (totais do mês não mudam).
enum FlowFilter { todos, recebido, aReceber, inadimplente }

/// Inadimplente = pendente com vencimento antes de hoje (dia, sem hora).
/// Puro e testado.
bool isOverdueTx(TransactionItem t, DateTime now) {
  if (t.isPaid) return false;
  final day = DateTime(now.year, now.month, now.day);
  return t.dueDate.isBefore(day);
}

/// Aplica o filtro (puro e testado).
List<TransactionItem> flowFilter(
  List<TransactionItem> items,
  FlowFilter f,
  DateTime now,
) {
  switch (f) {
    case FlowFilter.todos:
      return List.of(items);
    case FlowFilter.recebido:
      return [
        for (final t in items)
          if (t.isPaid) t,
      ];
    case FlowFilter.aReceber:
      return [
        for (final t in items)
          if (!t.isPaid && !isOverdueTx(t, now)) t,
      ];
    case FlowFilter.inadimplente:
      return [
        for (final t in items)
          if (isOverdueTx(t, now)) t,
      ];
  }
}

class OracleReportSnapshot {
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;
  final double projectedBalance;
  final List<TransactionItem> transactions;

  OracleReportSnapshot({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitMargin,
    required this.projectedBalance,
    required this.transactions,
  });

  double get totalIncome => totalRevenue;
  double get totalExpense => totalExpenses;
}

class ReportDocument {
  const ReportDocument(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

DateTime? reportDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : value is String
    ? DateTime.tryParse(value)
    : null;
bool reportCanceled(Map<String, dynamic> data) =>
    '${data['status'] ?? ''}'.toLowerCase().contains('cancel') ||
    FinancialModel.isReplaced('${data['status'] ?? ''}');
bool reportCard(Map<String, dynamic> data) {
  final method = '${data['paymentMethod'] ?? ''}'.toLowerCase();
  return !method.contains('déb') &&
      !method.contains('deb') &&
      (method.contains('cart') ||
          method.contains('crédit') ||
          method.contains('credit'));
}

bool reportAnticipated(Map<String, dynamic> data) =>
    '${data['status'] ?? ''}'.toLowerCase().contains('anticipat') ||
    '${data['status'] ?? ''}'.toLowerCase().contains('antecipad');
bool reportCanAnticipate(Map<String, dynamic> data, DateTime now) {
  final date = reportDate(data['dueDate']) ?? reportDate(data['date']);
  return (data['type'] ?? 'income') == 'income' &&
      reportCard(data) &&
      !reportCanceled(data) &&
      !reportAnticipated(data) &&
      date != null &&
      !date.isBefore(DateTime(now.year, now.month, now.day)) &&
      !date.isAfter(DateTime(now.year + 1, now.month, now.day)) &&
      parseBRL(data['amount']) > 0;
}

class OracleReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<OracleReportSnapshot> getMonthOverview(DateTime month) {
    final String? clinicId = SessionManager().currentClinicId;

    if (clinicId == null) {
      return Stream.value(
        OracleReportSnapshot(
          totalRevenue: 0,
          totalExpenses: 0,
          netProfit: 0,
          profitMargin: 0,
          projectedBalance: 0,
          transactions: [],
        ),
      );
    }

    DateTime start = DateTime(month.year, month.month, 1);
    DateTime end = DateTime(month.year, month.month + 1, 1);

    // Economia de cota: união de queries mensais por campo de data em vez
    // de baixar a collection inteira. Exato porque toda data efetiva usada
    // abaixo (due/payment/paid/date) tem sua query; o mapa por id dedupica.
    // (Exige os índices clinicId+<campo> em firestore.indexes.json.)
    Stream<QuerySnapshot> bounded(String collection, String field) {
      return _db
          .collection(collection)
          .where('clinicId', isEqualTo: clinicId)
          .where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where(field, isLessThan: Timestamp.fromDate(end))
          .snapshots();
    }

    const dateFields = [
      'dueDate',
      'paymentDate',
      'paidDate',
      'date',
      'createdAt',
    ];
    final incomeStreams = dateFields
        .where((f) => f != 'createdAt')
        .map((f) => bounded('financial', f))
        .toList();
    final expenseStreams = dateFields
        .map((f) => bounded('expenses', f))
        .toList();

    return StreamCombiner.combineDocs([
      ...incomeStreams,
      ...expenseStreams,
    ]).map(
      (lists) => _processDocs(
        lists.sublist(0, 4).expand((l) => l).toList(),
        lists.sublist(4).expand((l) => l).toList(),
        start,
        end,
      ),
    );
  }

  Stream<List<ReportDocument>> getCardReceivables() {
    final clinic = SessionManager().currentClinicId;
    if (clinic == null) return Stream.value([]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = DateTime(now.year + 1, now.month, now.day);
    final streams = ['dueDate', 'date']
        .map(
          (field) => SessionManager()
              .applyFilter(_db.collection('financial'))
              .where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(today))
              .where(field, isLessThanOrEqualTo: Timestamp.fromDate(horizon))
              .snapshots(),
        )
        .toList();
    return StreamCombiner.combineDocs(streams).map((lists) {
      final docs = <String, ReportDocument>{};
      for (final d in lists.expand((l) => l)) {
        final data = d.data() as Map<String, dynamic>;
        final effective =
            reportDate(data['dueDate']) ?? reportDate(data['date']);
        if (effective != null &&
            !effective.isBefore(today) &&
            !effective.isAfter(horizon) &&
            (data['type'] ?? 'income') == 'income' &&
            reportCard(data) &&
            !reportCanceled(data)) {
          docs[d.id] = ReportDocument(d.id, data);
        }
      }
      return docs.values.toList()..sort(
        (a, b) => (reportDate(a.data['dueDate']) ?? reportDate(a.data['date'])!)
            .compareTo(
              reportDate(b.data['dueDate']) ?? reportDate(b.data['date'])!,
            ),
      );
    });
  }

  OracleReportSnapshot _processDocs(
    List<QueryDocumentSnapshot> incomes,
    List<QueryDocumentSnapshot> expenses,
    DateTime start,
    DateTime end,
  ) => calculateMonth(
    DateTime(start.year, start.month),
    [
      for (final d in incomes)
        ReportDocument(d.id, d.data() as Map<String, dynamic>),
    ],
    [
      for (final d in expenses)
        ReportDocument(d.id, d.data() as Map<String, dynamic>),
    ],
  );

  /// Same cash/receivables basis used by the existing Livro Caixa, now shared by DRE.
  static OracleReportSnapshot calculateMonth(
    DateTime month,
    List<ReportDocument> incomes,
    List<ReportDocument> expenses,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    ).subtract(const Duration(microseconds: 1));
    Map<String, TransactionItem> uniqueItems = {};

    // --- PROCESSAR RECEITAS (O REGIME DE CAIXA) ---
    for (var doc in incomes) {
      final data = doc.data;

      String id = doc.id;
      if (reportCanceled(data)) continue;
      if ((data['type'] ?? 'income') != 'income') continue;
      String patientName = data['patientName'] ?? 'Receita Avulsa';
      double amount = parseBRL(data['amount']);
      // Definição única de "pago" (+ flag crua legada).
      bool isPaid =
          FinancialModel.isPaidOf(
            status: data['status']?.toString() ?? '',
            paidAmount: data['paidAmount'],
            amount: data['amount'],
          ) ||
          data['isPaid'] == true;
      String status = (data['status'] ?? '').toString().toLowerCase().trim();
      String method = data['paymentMethod'] ?? 'Dinheiro';

      bool isCreditCard = reportCard(data);
      bool isAnticipated =
          status.contains('anticipat') || status.contains('antecipad');
      bool isCanceled =
          status.contains('cancel') || status.contains('substitu');

      if (isCanceled) continue; // Expulsa cancelados e substituídos

      DateTime? storedDate =
          reportDate(data['date']) ??
          reportDate(data['createdAt']) ??
          reportDate(data['dueDate']) ??
          reportDate(data['paidDate']) ??
          reportDate(data['paymentDate']);
      if (storedDate == null) continue;
      DateTime date = storedDate;
      DateTime dueDate = reportDate(data['dueDate']) ?? date;
      DateTime? paidDate =
          reportDate(data['paidDate']) ?? reportDate(data['paymentDate']);

      DateTime effectiveDate;

      // O NOVO CÉREBRO: Quando o dinheiro cai na conta?
      if (isCreditCard) {
        if (isAnticipated) {
          effectiveDate = paidDate ?? date; // Puxa para hoje
          isPaid = true; // Se antecipou, o dinheiro já está na mão
        } else {
          effectiveDate = dueDate; // Viaja no tempo para o mês do Vencimento
          // Mantém isPaid como false para aparecer como "PENDENTE" até ao vencimento
        }
      } else {
        if (isPaid) {
          effectiveDate = paidDate ?? date;
        } else {
          effectiveDate = dueDate;
        }
      }

      // Se a data efetiva cair no mês que estamos a olhar, entra no Livro!
      if (_isInMonth(effectiveDate, start, end)) {
        uniqueItems['income:$id'] = TransactionItem(
          id: id,
          title: patientName,
          amount: amount,
          date: effectiveDate,
          dueDate: dueDate,
          paidAmount: parseBRL(data['paidAmount']),
          isIncome: true,
          isPaid: isPaid,
          category: "Receita",
          patientId: data['patientId'],
          paymentMethod: method,
          details: Map.unmodifiable(data),
        );
      }
    }

    // --- PROCESSAR DESPESAS ---
    for (var doc in expenses) {
      final data = doc.data;
      String id = doc.id;
      if (reportCanceled(data)) continue;
      String description =
          (data['description']?.toString().trim().isNotEmpty ?? false)
          ? data['description'].toString()
          : (data['title'] ?? 'Despesa').toString();
      double amount = parseBRL(data['amount']);
      final dueDate =
          reportDate(data['dueDate']) ??
          reportDate(data['date']) ??
          reportDate(data['createdAt']) ??
          reportDate(data['paidDate']) ??
          reportDate(data['paymentDate']);
      if (dueDate == null) continue;
      DateTime? paidDate =
          reportDate(data['paidDate']) ?? reportDate(data['paymentDate']);

      String category = data['category'] ?? 'Geral';
      String method = data['paymentMethod'] ?? 'Boleto/Outros';
      bool expIsPaid =
          FinancialModel.isPaidOf(
            status: data['status']?.toString() ?? '',
            paidAmount: data['paidAmount'],
            amount: data['amount'],
          ) ||
          data['isPaid'] == true;

      DateTime effectiveDate = expIsPaid ? (paidDate ?? dueDate) : dueDate;

      if (_isInMonth(effectiveDate, start, end)) {
        uniqueItems['expense:$id'] = TransactionItem(
          id: id,
          title: description,
          amount: amount,
          date: effectiveDate,
          dueDate: dueDate,
          paidAmount: parseBRL(data['paidAmount']),
          isIncome: false,
          isPaid: expIsPaid,
          category: category,
          paymentMethod: method,
          details: Map.unmodifiable(data),
        );
      }
    }

    // --- FINALIZAÇÃO E CÁLCULO DE SALDOS ---
    var items = uniqueItems.values.toList();
    items.sort((a, b) => a.date.compareTo(b.date));

    double revenue = 0;
    double expense = 0;
    double balance = 0;

    for (var item in items) {
      if (item.isPaid) {
        if (item.isIncome) {
          revenue += item.amount;
        } else {
          expense += item.amount;
        }
      }
      // Projetado usa o SALDO (desconta parciais de pendentes).
      final projected = item.isPaid
          ? item.amount
          : (item.amount - item.paidAmount);
      if (item.isIncome) {
        balance += projected;
      } else {
        balance -= projected;
      }
      item.runningBalance = balance;
    }

    return OracleReportSnapshot(
      totalRevenue: revenue,
      totalExpenses: expense,
      netProfit: revenue - expense,
      profitMargin: revenue == 0 ? 0 : ((revenue - expense) / revenue) * 100,
      projectedBalance: balance,
      transactions: items,
    );
  }

  static bool _isInMonth(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && !date.isAfter(end);
  }
}

class StreamCombiner {
  static Stream<List<QuerySnapshot>> combine2(
    Stream<QuerySnapshot> s1,
    Stream<QuerySnapshot> s2,
  ) {
    StreamController<List<QuerySnapshot>> controller =
        StreamController<List<QuerySnapshot>>();
    List<QuerySnapshot?> values = [null, null];
    Set<int> filled = {};
    void emit() {
      if (filled.length == 2) controller.add(List<QuerySnapshot>.from(values));
    }

    void onError(Object e) {
      if (!controller.isClosed) controller.addError(e);
    }

    s1.listen((d) {
      values[0] = d;
      filled.add(0);
      emit();
    }, onError: onError);
    s2.listen((d) {
      values[1] = d;
      filled.add(1);
      emit();
    }, onError: onError);
    return controller.stream;
  }

  /// Junta N streams emitindo a lista das últimas listas de docs.
  static Stream<List<List<QueryDocumentSnapshot>>> combineDocs(
    List<Stream<QuerySnapshot>> streams,
  ) {
    final controller = StreamController<List<List<QueryDocumentSnapshot>>>();
    final values = List<List<QueryDocumentSnapshot>>.generate(
      streams.length,
      (_) => [],
    );
    final filled = <int>{};
    var closed = false;
    void emit() {
      if (!closed && filled.length == streams.length) {
        controller.add([for (final v in values) List.of(v)]);
      }
    }

    void onError(Object e) {
      if (!closed) controller.addError(e);
    }

    final subscriptions = <StreamSubscription<QuerySnapshot>>[];
    for (var i = 0; i < streams.length; i++) {
      subscriptions.add(
        streams[i].listen(
          (snap) {
            values[i] = snap.docs;
            filled.add(i);
            emit();
          },
          onError: onError,
          onDone: () {},
        ),
      );
    }
    controller.onCancel = () async {
      closed = true;
      await Future.wait(subscriptions.map((s) => s.cancel()));
    };
    return controller.stream;
  }
}
