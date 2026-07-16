import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String clinicId;
  final String title;
  final String description;
  final double amount;
  
  final DateTime date;        // Competência
  final DateTime dueDate;     // Vencimento
  final DateTime? paidDate;   // Data de Pagamento Realizado
  
  final String status;        // 'pendente', 'pago'
  final String category;
  final String? supplierId;
  final String? supplierName;
  
  final String? relatedPatientId; // Vínculo com Paciente
  final String? relatedPlanId;    // Vínculo com Orçamento/Tratamento
  final String? relatedFinancialId; // <--- NOVO: Vínculo com o Pagamento (Receita)
  
  final bool isCommission;

  ExpenseModel({
    required this.id,
    required this.clinicId,
    this.title = '',
    required this.description,
    required this.amount,
    required this.date,
    required this.dueDate,
    this.paidDate,
    required this.status,
    required this.category,
    this.supplierId,
    this.supplierName,
    this.relatedPatientId,
    this.relatedPlanId,
    this.relatedFinancialId, // <--- Novo parâmetro
    this.isCommission = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'title': title,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'dueDate': Timestamp.fromDate(dueDate),
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'status': status,
      'category': category,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'relatedPatientId': relatedPatientId,
      'relatedPlanId': relatedPlanId,
      'relatedFinancialId': relatedFinancialId, // <--- Salva no banco
      'isCommission': isCommission,
    };
  }

  factory ExpenseModel.fromMap(String id, Map<String, dynamic> map) {
    return ExpenseModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: map['date'] != null 
          ? (map['date'] as Timestamp).toDate() 
          : (map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : DateTime.now()),
      dueDate: map['dueDate'] != null 
          ? (map['dueDate'] as Timestamp).toDate() 
          : DateTime.now(),
      paidDate: map['paidDate'] != null ? (map['paidDate'] as Timestamp).toDate() : null,
      status: map['status'] ?? 'pendente',
      category: map['category'] ?? 'Geral',
      supplierId: map['supplierId'],
      supplierName: map['supplierName'],
      relatedPatientId: map['relatedPatientId'],
      relatedPlanId: map['relatedPlanId'],
      relatedFinancialId: map['relatedFinancialId'], // <--- Lê do banco
      isCommission: map['isCommission'] ?? false,
    );
  }
}