import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/display.dart';

class BudgetModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final double total;
  final String status; // 'Pendente', 'Aprovado'
  final List<Map<String, dynamic>> items;
  final DateTime date;
  final Map<String, dynamic> details;
  final bool dateKnown;

  BudgetModel({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    required this.total,
    required this.status,
    required this.items,
    required this.date,
    this.details = const {},
    this.dateKnown = true,
  });

  factory BudgetModel.fromMap(String id, Map<String, dynamic> map) {
    return BudgetModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      total: parseBRL(map['total'] ?? map['totalValue']),
      status: map['status'] ?? 'Pendente',
      items: [
        if (map['items'] is List)
          for (final item in map['items'])
            if (item is Map) Map<String, dynamic>.from(item),
      ],
      date: budgetDate(map['date']) ?? DateTime(1970),
      dateKnown: budgetDate(map['date']) != null,
      details: Map.unmodifiable(map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...details,
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

DateTime? budgetDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : value is String
    ? DateTime.tryParse(value)
    : null;

enum BudgetGroup { all, approved, pending, declined, other }

BudgetGroup budgetGroup(BudgetModel b, DateTime now) {
  final status = b.status.toLowerCase().trim();
  if (['aprovado', 'approved', 'aceito', 'accepted'].contains(status)) {
    return BudgetGroup.approved;
  }
  if (status.contains('recus') ||
      status.contains('rejeit') ||
      status.contains('declin') ||
      status.contains('expir') ||
      status.contains('cancel')) {
    return BudgetGroup.declined;
  }
  if ([
    'pendente',
    'pending',
    'em negociação',
    'negociacao',
    'negociação',
    'aberto',
    'open',
  ].contains(status)) {
    final valid = budgetDate(b.details['validUntil'] ?? b.details['expiresAt']);
    if (valid != null &&
        DateTime(
          now.year,
          now.month,
          now.day,
        ).isAfter(DateTime(valid.year, valid.month, valid.day))) {
      return BudgetGroup.declined;
    }
    return BudgetGroup.pending;
  }
  return BudgetGroup.other;
}

String budgetTitle(BudgetModel b) {
  final code = '${b.details['number'] ?? b.details['code'] ?? ''}'.trim();
  return code.isNotEmpty
      ? 'Orçamento #$code'
      : b.dateKnown
      ? 'Orçamento – ${formatDateFull(b.date)}'
      : 'Orçamento';
}

Uri? budgetLink(Object? value) {
  final uri = Uri.tryParse('$value');
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

class BudgetItemDisplay {
  BudgetItemDisplay(this.data);
  final Map<String, dynamic> data;
  String get name => '${data['name'] ?? 'Procedimento'}';
  double get quantity => parseBRL(data['quantity'] ?? data['qty'] ?? 1) > 0
      ? parseBRL(data['quantity'] ?? data['qty'] ?? 1)
      : 1;
  double get discount => parseBRL(data['discountAmount']);
  double get subtotal => parseBRL(data['price'] ?? data['subtotal']);
  double get unitPrice => data['unitPrice'] != null
      ? parseBRL(data['unitPrice'])
      : (subtotal + discount) / quantity;
  String get region {
    final raw =
        data['region'] ?? data['teeth'] ?? data['tooth'] ?? data['toothNumber'];
    if (raw is List && raw.isNotEmpty) return raw.join(', ');
    return raw == null || '$raw'.trim().isEmpty ? 'Não informado' : '$raw';
  }
}
