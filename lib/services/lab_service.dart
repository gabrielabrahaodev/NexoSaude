import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab_order.dart';
import 'session_manager.dart';
import '../models/expense_model.dart';
import 'clinic_capabilities.dart';

class LabService {
  LabService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  static const _requestFields = [
    'clinicId',
    'patientId',
    'supplierId',
    'description',
    'price',
    'relatedPlanId',
    'workType',
    'costDueDate',
    'deliveryDate',
    'dentistId',
    'procedureName',
  ];

  String newOrderId() => _db.collection('lab_orders').doc().id;

  /// Independent payable: no link to a patient receipt or payment method.
  static Map<String, dynamic>? expenseFor(
    LabOrderModel order, {
    required String orderId,
  }) {
    if (!order.price.isFinite ||
        order.price < 0 ||
        (order.price > 0 && order.price < .01)) {
      throw ArgumentError('Custo inválido.');
    }
    if (order.price == 0) return null;
    if (order.costDueDate == null) {
      throw ArgumentError('Informe o vencimento do custo.');
    }
    return {
      ...ExpenseModel(
        id: 'lab_$orderId',
        clinicId: order.clinicId,
        title: 'Laboratório - ${order.patientName}',
        description: '${order.description} — ${order.patientName}',
        amount: order.price,
        date: order.createdAt,
        dueDate: order.costDueDate!,
        status: 'pendente',
        category: 'Laboratório',
        supplierId: order.supplierId,
        supplierName: order.supplierName,
        relatedPatientId: order.patientId,
        relatedPlanId: order.relatedPlanId,
      ).toMap(),
      'source': 'lab_order',
      'relatedLabOrderId': orderId,
    };
  }

  /// One stable ID per dialog; retries create neither a second order nor a second cost.
  Future<void> createOrder(LabOrderModel order) async {
    final clinic = SessionManager().currentClinicId;
    if (!ClinicCapabilities.current().canShowLab ||
        clinic == null ||
        order.clinicId != clinic ||
        order.patientId.isEmpty ||
        order.description.trim().isEmpty ||
        order.supplierId == null) {
      throw StateError('Confira a clínica, o paciente e o laboratório.');
    }
    final ref = _db
        .collection('lab_orders')
        .doc(order.id.isEmpty ? null : order.id);
    final expense = expenseFor(order, orderId: ref.id);
    // The patient's existing clinical_data rules allow reading a missing receipt.
    // Reading a new top-level lab_orders document would be denied by current rules.
    final receipt = _db
        .collection('patients/${order.patientId}/clinical_data')
        .doc('lab_request_${ref.id}');
    await _db.runTransaction((tx) async {
      final previous = await tx.get(receipt);
      if (previous.exists) {
        final data = previous.data()!;
        if (data['clinicId'] != clinic ||
            data['patientId'] != order.patientId ||
            _requestFields.any((key) => data[key] != order.toMap()[key])) {
          throw StateError(
            'Este pedido já foi registrado com outros dados. Confira o kanban antes de tentar novamente.',
          );
        }
        return;
      }
      final patient = await tx.get(
        _db.collection('patients').doc(order.patientId),
      );
      final supplier = await tx.get(
        _db.collection('suppliers').doc(order.supplierId),
      );
      if (patient.data()?['clinicId'] != clinic ||
          supplier.data()?['clinicId'] != clinic) {
        throw StateError(
          'Paciente ou laboratório não pertence à clínica atual.',
        );
      }
      if (order.relatedPlanId != null) {
        final plan = await tx.get(
          _db.collection('treatment_plans').doc(order.relatedPlanId),
        );
        if (plan.data()?['clinicId'] != clinic ||
            plan.data()?['patientId'] != order.patientId) {
          throw StateError('Tratamento não pertence a este paciente.');
        }
      }
      if (SessionManager().currentClinicId != clinic) {
        throw StateError('A unidade foi alterada.');
      }
      tx.set(ref, {
        ...order.toMap(),
        'relatedFinancialId': null,
        'relatedExpenseId': expense == null ? null : 'lab_${ref.id}',
        'hasCost': expense != null,
      });
      if (expense != null) {
        tx.set(_db.collection('expenses').doc('lab_${ref.id}'), expense);
      }
      final request = order.toMap();
      tx.set(receipt, {
        for (final key in _requestFields) key: request[key],
        'labOrderId': ref.id,
        'expenseId': expense == null ? null : 'lab_${ref.id}',
      });
    });
  }

  Future<void> deleteOrder(String id) async {
    await _db.collection('lab_orders').doc(id).delete();
  }

  Stream<List<LabOrderModel>> getByPatient(String patientId) {
    return SessionManager()
        .applyFilter(
          _db.collection('lab_orders').where('patientId', isEqualTo: patientId),
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LabOrderModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<LabOrderModel>> getByClinic(String clinicId) {
    return _db
        .collection('lab_orders')
        .where('clinicId', isEqualTo: clinicId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LabOrderModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> updateStatus(
    String id,
    String newStatus,
    Map<String, dynamic> additionalData,
  ) async {
    Map<String, dynamic> data = {'status': newStatus};
    data.addAll(additionalData);
    await _db.collection('lab_orders').doc(id).update(data);
  }

  Future<void> addInteraction(
    String orderId,
    LabInteraction interaction,
  ) async {
    await _db.collection('lab_orders').doc(orderId).update({
      'interactions': FieldValue.arrayUnion([interaction.toMap()]),
    });
  }
}
