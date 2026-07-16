import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final double total;
  final String status; // 'Pendente', 'Aprovado'
  final List<Map<String, dynamic>> items;
  final DateTime date;

  BudgetModel({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    required this.total,
    required this.status,
    required this.items,
    required this.date,
  });

  factory BudgetModel.fromMap(String id, Map<String, dynamic> map) {
    return BudgetModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      total: (map['total'] ?? map['totalValue'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'Pendente',
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      date: (map['date'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'patientId': patientId,
      'patientName': patientName,
      'total': total,
      'status': status,
      'items': items,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}