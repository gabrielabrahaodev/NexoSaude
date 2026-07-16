import 'package:cloud_firestore/cloud_firestore.dart';

class LabInteraction {
  final String text;
  final DateTime date;
  final String author;
  final bool isProblem;

  LabInteraction({
    required this.text,
    required this.date,
    required this.author,
    this.isProblem = false,
  });

  Map<String, dynamic> toMap() => {
    'text': text,
    'date': Timestamp.fromDate(date),
    'author': author,
    'isProblem': isProblem,
  };

  factory LabInteraction.fromMap(Map<String, dynamic> map) {
    return LabInteraction(
      text: map['text'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      author: map['author'] ?? 'Sistema',
      isProblem: map['isProblem'] ?? false,
    );
  }
}

class LabOrderModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final String? dentistId;
  final String? dentistName;
  final String? supplierId;
  final String? supplierName;
  final String? relatedPlanId;
  final String description;
  final String procedureName;
  final double price;
  
  // Datas importantes
  final DateTime createdAt;
  final DateTime? sentDate;
  final DateTime? returnDate;
  final DateTime? deliveredDate; 
  final DateTime? deliveryDate;  

  final String status;
  final String? relatedFinancialId;
  final List<LabInteraction> interactions;

  LabOrderModel({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    this.dentistId,
    this.dentistName,
    this.supplierId,
    this.supplierName,
    this.relatedPlanId,
    required this.description,
    this.procedureName = '',
    this.price = 0.0,
    required this.createdAt,
    this.sentDate,
    this.returnDate,
    this.deliveredDate,
    this.deliveryDate,
    this.status = 'Solicitado',
    this.relatedFinancialId,
    this.interactions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'patientId': patientId,
      'patientName': patientName,
      'dentistId': dentistId,
      'dentistName': dentistName,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'relatedPlanId': relatedPlanId,
      'description': description,
      'procedureName': procedureName,
      'price': price,
      'createdAt': Timestamp.fromDate(createdAt),
      'sentDate': sentDate != null ? Timestamp.fromDate(sentDate!) : null,
      'returnDate': returnDate != null ? Timestamp.fromDate(returnDate!) : null,
      'deliveredDate': deliveredDate != null ? Timestamp.fromDate(deliveredDate!) : null,
      'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'status': status,
      'relatedFinancialId': relatedFinancialId,
      'interactions': interactions.map((i) => i.toMap()).toList(),
    };
  }

  factory LabOrderModel.fromMap(String id, Map<String, dynamic> map) {
    // CORREÇÃO DE DATA: Tenta ler 'createdAt', se não achar, tenta 'createdDate'
    // Se não achar nenhum, usa data atual.
    DateTime created;
    if (map['createdAt'] != null) {
      created = (map['createdAt'] as Timestamp).toDate();
    } /*else if (map['createdDate'] != null) {
      created = (map['createdDate'] as Timestamp).toDate();
    }*/ else {
      created = DateTime.now();
    }

    return LabOrderModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Paciente',
      dentistId: map['dentistId'],
      dentistName: map['dentistName'],
      supplierId: map['supplierId'],
      supplierName: map['supplierName'],
      relatedPlanId: map['relatedPlanId'],
      description: map['description'] ?? '',
      procedureName: map['procedureName'] ?? map['description'] ?? 'Pedido Lab',
      price: (map['price'] ?? map['cost'] ?? 0).toDouble(),
      
      createdAt: created, // Usa a data corrigida
      
      sentDate: map['sentDate'] != null ? (map['sentDate'] as Timestamp).toDate() : null,
      returnDate: map['returnDate'] != null ? (map['returnDate'] as Timestamp).toDate() : null,
      deliveredDate: map['deliveredDate'] != null ? (map['deliveredDate'] as Timestamp).toDate() : null,
      deliveryDate: map['deliveryDate'] != null ? (map['deliveryDate'] as Timestamp).toDate() : null,
      status: map['status'] ?? 'Solicitado',
      relatedFinancialId: map['relatedFinancialId'],
      interactions: (map['interactions'] as List<dynamic>? ?? [])
          .map((i) => LabInteraction.fromMap(i as Map<String, dynamic>))
          .toList(),
    );
  }
}