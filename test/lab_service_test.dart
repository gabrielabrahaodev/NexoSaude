// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/lab_order.dart';
import 'package:odonto_controle/models/expense_model.dart';
import 'package:odonto_controle/services/lab_service.dart';
import 'package:odonto_controle/services/session_manager.dart';

class _Doc<T extends Object?> extends Fake implements DocumentReference<T> {
  _Doc(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Doc('${this.path}/${path ?? 'generated'}');
}

class _Snapshot<T extends Object?> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.db);
  final _Db db;
  final pending = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    db.onRead?.call(ref.path);
    return _Snapshot<T>(db.docs[ref.path] as T?);
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    if (db.rejectExpense && ref.path.startsWith('expenses/')) {
      throw StateError('Escrita recusada');
    }
    pending[ref.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

class _Db extends Fake implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{
    'patients/p1': {'clinicId': 'c1'},
    'suppliers/l1': {'clinicId': 'c1'},
    'treatment_plans/t1': {'clinicId': 'c1', 'patientId': 'p1'},
  };
  bool rejectExpense = false, retry = false;
  void Function(String)? onRead;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (retry) await transactionHandler(_Transaction(this));
    final tx = _Transaction(this);
    final result = await transactionHandler(tx);
    docs.addAll(tx.pending);
    return result;
  }
}

LabOrderModel order({
  double cost = 120,
  String clinic = 'c1',
  String patient = 'p1',
  String supplier = 'l1',
  String? plan = 't1',
  String description = 'Coroa',
  DateTime? due,
}) => LabOrderModel(
  id: 'os1',
  clinicId: clinic,
  patientId: patient,
  patientName: 'Gabriel',
  supplierId: supplier,
  supplierName: 'Lab real',
  relatedPlanId: plan,
  description: description,
  price: cost,
  createdAt: DateTime(2026, 10, 31),
  costDueDate: cost > 0 ? due ?? DateTime(2026, 11, 10) : null,
);

void main() {
  setUp(() => SessionManager().setClinic('c1', 'Clínica', 'dental'));
  test(
    'pedido com custo gera um débito pendente compatível com A Pagar',
    () async {
      final db = _Db();
      await LabService(firestore: db).createOrder(order());
      final expense = ExpenseModel.fromMap(
        'lab_os1',
        db.docs['expenses/lab_os1']!,
      );
      expect(expense.amount, 120);
      expect(expense.status, 'pendente');
      expect(expense.paidDate, isNull);
      expect(expense.category, 'Laboratório');
      expect(expense.dueDate, DateTime(2026, 11, 10));
      expect(expense.relatedPatientId, 'p1');
      expect(expense.relatedPlanId, 't1');
      expect(expense.relatedFinancialId, isNull);
      expect(db.docs['expenses/lab_os1']!['relatedLabOrderId'], 'os1');
      expect(db.docs['lab_orders/os1']!['relatedExpenseId'], 'lab_os1');
      expect(db.docs['lab_orders/os1']!['relatedFinancialId'], isNull);
    },
  );
  test(
    'sem custo cria somente pedido, inclusive com retry da transação',
    () async {
      final db = _Db()..retry = true;
      await LabService(firestore: db).createOrder(order(cost: 0));
      expect(db.docs.keys.where((p) => p.startsWith('expenses/')), isEmpty);
      expect(db.docs['lab_orders/os1']!['hasCost'], false);
    },
  );
  test(
    'falha na despesa não deixa pedido parcial; retry/reenvio não duplica',
    () async {
      final db = _Db()..rejectExpense = true;
      final service = LabService(firestore: db);
      await expectLater(service.createOrder(order()), throwsStateError);
      expect(db.docs['lab_orders/os1'], isNull);
      db.rejectExpense = false;
      db.retry = true;
      await service.createOrder(order());
      await service.createOrder(order());
      expect(db.docs.keys.where((p) => p.startsWith('expenses/')).length, 1);
      expect(db.docs.keys.where((p) => p.startsWith('lab_orders/')).length, 1);
      await expectLater(
        service.createOrder(order(description: 'Outro pedido')),
        throwsStateError,
      );
    },
  );
  for (final collection in [
    'patients/p1',
    'suppliers/l1',
    'treatment_plans/t1',
  ]) {
    test('recusa vínculo de outra clínica: $collection', () async {
      final db = _Db();
      db.docs[collection]!['clinicId'] = 'c2';
      await expectLater(
        LabService(firestore: db).createOrder(order()),
        throwsStateError,
      );
      expect(db.docs['lab_orders/os1'], isNull);
      expect(db.docs['expenses/lab_os1'], isNull);
    });
  }
  test(
    'recusa plano de outro paciente e troca de unidade durante criação',
    () async {
      final db = _Db();
      db.docs['treatment_plans/t1']!['patientId'] = 'p2';
      await expectLater(
        LabService(firestore: db).createOrder(order()),
        throwsStateError,
      );
      db.docs['treatment_plans/t1']!['patientId'] = 'p1';
      db.onRead = (path) {
        if (path.startsWith('suppliers/')) {
          SessionManager().setClinic('c2', 'Outra', 'dental');
        }
      };
      await expectLater(
        LabService(firestore: db).createOrder(order()),
        throwsStateError,
      );
      expect(db.docs['lab_orders/os1'], isNull);
    },
  );
  test(
    'custo inválido nunca cria débito; dados legados continuam legíveis',
    () {
      for (final cost in [-1.0, double.nan, double.infinity, .001]) {
        expect(
          () => LabService.expenseFor(order(cost: cost), orderId: 'x'),
          throwsArgumentError,
        );
      }
      final legacy = LabOrderModel.fromMap('old', {
        'cost': '12.50',
        'status': 'Solicitado',
      });
      expect(legacy.price, 12.5);
      expect(legacy.hasCost, isNull);
      expect(legacy.workType, isNull);
      expect(legacy.relatedFinancialId, isNull);
    },
  );
}
