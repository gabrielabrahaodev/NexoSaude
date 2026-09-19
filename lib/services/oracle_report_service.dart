import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import '../models/financial_model.dart';

// --- MODELOS AUXILIARES ---
class TransactionItem {
  final String id;
  final String title; 
  final double amount;
  final DateTime date; 
  final bool isIncome;
  final bool isPaid;
  final String category;
  
  final String? patientId; 
  final String paymentMethod; 

  double runningBalance;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isIncome,
    required this.isPaid,
    required this.category,
    this.patientId,      
    this.paymentMethod = 'Dinheiro', 
    this.runningBalance = 0.0,
  });
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

class OracleReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<OracleReportSnapshot> getMonthOverview(DateTime month) {
    final String? clinicId = SessionManager().currentClinicId;
    
    if (clinicId == null) {
      return Stream.value(OracleReportSnapshot(
        totalRevenue: 0, totalExpenses: 0, netProfit: 0, profitMargin: 0, projectedBalance: 0, transactions: []
      ));
    }

    DateTime start = DateTime(month.year, month.month, 1);
    DateTime end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // MÁGICA DE PERFORMANCE E ANTI-CRASH: Puxamos os dados mestres e fazemos o roteamento na memória
    // Evita crashes por falta de Índices (Indexes) no Firebase.
    var incomes = _db.collection('financial').where('clinicId', isEqualTo: clinicId).snapshots();
    var expenses = _db.collection('expenses').where('clinicId', isEqualTo: clinicId).snapshots();

    return StreamCombiner.combine2(incomes, expenses)
        .map((snaps) => _processSnapshots(snaps, start, end));
  }

  OracleReportSnapshot _processSnapshots(List<QuerySnapshot> snaps, DateTime start, DateTime end) {
    Map<String, TransactionItem> uniqueItems = {};

    // --- PROCESSAR RECEITAS (O REGIME DE CAIXA) ---
    for (var doc in snaps[0].docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      String id = doc.id;
      String patientName = data['patientName'] ?? 'Receita Avulsa';
      double amount = (data['amount'] ?? 0).toDouble();
      // Definição única de "pago" (+ flag crua legada).
      bool isPaid = FinancialModel.isPaidOf(
            status: data['status']?.toString() ?? '',
            paidAmount: data['paidAmount'],
            amount: data['amount'],
          ) ||
          data['isPaid'] == true;
      String status = (data['status'] ?? '').toString().toLowerCase().trim();
      String method = data['paymentMethod'] ?? 'Dinheiro'; 

      bool isCreditCard = method.toLowerCase().contains('cart') || method.toLowerCase().contains('credit');
      bool isAnticipated = status.contains('anticipat') || status.contains('antecipad');
      bool isCanceled = status.contains('cancel');

      if (isCanceled) continue; // Expulsa cancelados

      DateTime date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      DateTime dueDate = (data['dueDate'] as Timestamp?)?.toDate() ?? date;
      DateTime? paidDate = (data['paidDate'] as Timestamp?)?.toDate() ?? (data['paymentDate'] as Timestamp?)?.toDate();

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
        uniqueItems[id] = TransactionItem(
          id: id,
          title: patientName,
          amount: amount,
          date: effectiveDate,
          isIncome: true,
          isPaid: isPaid,
          category: "Receita",
          patientId: data['patientId'], 
          paymentMethod: method,
        );
      }
    }

    // --- PROCESSAR DESPESAS ---
    for (var doc in snaps[1].docs) {
      final data = doc.data() as Map<String, dynamic>;
      String id = doc.id;
      String description = data['description'] ?? 'Despesa';
      double amount = (data['amount'] ?? 0).toDouble();
      String status = (data['status'] ?? '').toString().toLowerCase().trim();
      
      DateTime dueDate = (data['dueDate'] as Timestamp?)?.toDate() ?? (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      DateTime? paidDate = (data['paidDate'] as Timestamp?)?.toDate() ?? (data['paymentDate'] as Timestamp?)?.toDate();
      
      String category = data['category'] ?? 'Geral';
      String method = data['paymentMethod'] ?? 'Boleto/Outros';
      bool expIsPaid = FinancialModel.isPaidOf(
            status: data['status']?.toString() ?? '',
            paidAmount: data['paidAmount'],
            amount: data['amount'],
          ) ||
          data['isPaid'] == true;

      DateTime effectiveDate = expIsPaid ? (paidDate ?? dueDate) : dueDate;

      if (_isInMonth(effectiveDate, start, end)) {
        uniqueItems[id] = TransactionItem(
          id: id,
          title: description,
          amount: amount,
          date: effectiveDate,
          isIncome: false,
          isPaid: expIsPaid, 
          category: category,
          paymentMethod: method,
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
        if (item.isIncome) revenue += item.amount; else expense += item.amount;
      }
      if (item.isIncome) balance += item.amount; else balance -= item.amount;
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

  bool _isInMonth(DateTime date, DateTime start, DateTime end) {
    return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
           date.isBefore(end.add(const Duration(seconds: 1)));
  }
}

class StreamCombiner {
  static Stream<List<QuerySnapshot>> combine2(Stream<QuerySnapshot> s1, Stream<QuerySnapshot> s2) {
    StreamController<List<QuerySnapshot>> controller = StreamController<List<QuerySnapshot>>();
    List<QuerySnapshot?> values = [null, null];
    Set<int> filled = {};
    void emit() { if (filled.length == 2) controller.add(List<QuerySnapshot>.from(values)); }
    void onError(Object e) { if (!controller.isClosed) controller.addError(e); }
    s1.listen((d) { values[0] = d; filled.add(0); emit(); }, onError: onError);
    s2.listen((d) { values[1] = d; filled.add(1); emit(); }, onError: onError);
    return controller.stream;
  }
}