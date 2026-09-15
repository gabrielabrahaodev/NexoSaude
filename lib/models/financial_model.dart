import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final String title;
  final String description;
  final double amount;
  final double paidAmount;
  final DateTime date;      // Data de registro
  final DateTime? dueDate;  // Data de vencimento
  final String type;        // 'income' (Receita) ou 'expense' (Despesa)
  final String status;      // 'pending', 'paid', 'anticipated'
  final String paymentMethod; 
  
  // Taxas e Valores Líquidos
  final double feePercentage;
  final double taxVal;
  final double valorLiquido;

  // Profissional
  final String? dentistId;
  final String? dentistName;

  // --- NOVOS CAMPOS (Antecipação e Máquina) ---
  final String? relatedBudgetId; 
  final String? machineProfileId; 
  final String? machineProfileName; 
  final double? anticipatedAmount; 

  // --- CAMPOS RESTAURADOS (Para compatibilidade com outras telas) ---
  final String? planId; 
  final String? installmentNumber; 

  // --- CAMPOS PARA PACOTES MENSAIS PSICOLOGIA ---
  final String? monthlyPeriod; // Formato "YYYY-MM"

  FinancialModel({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    required this.title,
    required this.description,
    required this.amount, // O Wizard deve usar 'amount', não 'value'
    this.paidAmount = 0.0,
    required this.date,
    this.dueDate,
    required this.type,
    this.status = 'pending',
    this.paymentMethod = 'Dinheiro',
    this.feePercentage = 0.0,
    this.taxVal = 0.0,
    this.valorLiquido = 0.0,
    this.dentistId,
    this.dentistName,
    this.relatedBudgetId,
    this.machineProfileId,
    this.machineProfileName,
    this.anticipatedAmount,
    this.planId,
    this.installmentNumber,
    this.monthlyPeriod,
  });

  // GETTER RESTAURADO: isPaid
  bool get isPaid => status == 'paid' || status == 'anticipated' || (paidAmount >= amount && amount > 0);

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'patientId': patientId,
      'patientName': patientName,
      'title': title,
      'description': description,
      'amount': amount,
      'paidAmount': paidAmount,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'type': type,
      'status': status,
      'paymentMethod': paymentMethod,
      'feePercentage': feePercentage,
      'taxVal': taxVal,
      'valorLiquido': valorLiquido,
      'dentistId': dentistId,
      'dentistName': dentistName,
      'relatedBudgetId': relatedBudgetId,
      'machineProfileId': machineProfileId,
      'machineProfileName': machineProfileName,
      'anticipatedAmount': anticipatedAmount,
      'planId': planId,
      'installmentNumber': installmentNumber,
      'monthlyPeriod': monthlyPeriod,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  factory FinancialModel.fromMap(String id, Map<String, dynamic> map) {
    return FinancialModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Paciente',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: _toDouble(map['amount']),
      paidAmount: _toDouble(map['paidAmount']),
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      dueDate: map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : null,
      type: map['type'] ?? 'income',
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? 'Dinheiro',
      feePercentage: _toDouble(map['feePercentage']),
      taxVal: _toDouble(map['taxVal']),
      valorLiquido: _toDouble(map['valorLiquido']),
      dentistId: map['dentistId'],
      dentistName: map['dentistName'],
      relatedBudgetId: map['relatedBudgetId'],
      machineProfileId: map['machineProfileId'],
      machineProfileName: map['machineProfileName'],
      anticipatedAmount: _toDouble(map['anticipatedAmount']),
      planId: map['planId'],
      installmentNumber: map['installmentNumber'],
      monthlyPeriod: map['monthlyPeriod'],
    );
  }
}