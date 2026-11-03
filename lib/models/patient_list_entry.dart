import '../utils/display.dart';
import '../services/oracle_report_service.dart' show ReportDocument, reportDate;
import 'financial_model.dart';
import 'budget_model.dart';

enum PatientListFilter { noConsent, debt, treatment, budget }

enum PatientListSort { alphabetic, recent, attendance }

String patientSearchKey(String text) {
  const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const plain = 'aaaaaeeeeiiiiooooouuuuc';
  var value = text.toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    value = value.replaceAll(accents[i], plain[i]);
  }
  return value;
}

class PatientListContext {
  const PatientListContext({
    this.debts = const {},
    this.treatments = const {},
    this.budgets = const {},
    this.attendance = const {},
  });
  final Map<String, double> debts;
  final Set<String> treatments, budgets;
  final Map<String, Map<String, dynamic>> attendance;
  static PatientListContext fromDocuments({
    required List<ReportDocument> financial,
    required List<ReportDocument> plans,
    required List<ReportDocument> quotes,
    required List<ReportDocument> appointments,
    required DateTime now,
  }) {
    final debts = <String, double>{};
    final treatments = <String>{};
    final budgets = <String>{};
    final visits = <String, Map<String, dynamic>>{};
    for (final doc in {for (final d in financial) d.id: d}.values) {
      final m = doc.data;
      final status = '${m['status'] ?? ''}'.toLowerCase();
      final id = '${m['patientId'] ?? ''}';
      if (id.isEmpty ||
          (m['type'] ?? 'income') != 'income' ||
          status.contains('cancel') ||
          FinancialModel.isReplaced(status) ||
          m['isPaid'] == true ||
          FinancialModel.isPaidOf(
            status: status,
            paidAmount: m['paidAmount'],
            amount: m['amount'],
          )) {
        continue;
      }
      final remainder = parseBRL(m['amount']) - parseBRL(m['paidAmount']);
      if (remainder.isFinite && remainder > 0) {
        debts.update(id, (v) => v + remainder, ifAbsent: () => remainder);
      }
    }
    for (final d in plans) {
      if (d.data['status'] == 'active' &&
          '${d.data['patientId'] ?? ''}'.isNotEmpty) {
        treatments.add('${d.data['patientId']}');
      }
    }
    for (final d in quotes) {
      final b = BudgetModel.fromMap(d.id, d.data);
      if (b.patientId.isNotEmpty &&
          budgetGroup(b, now) == BudgetGroup.pending) {
        budgets.add(b.patientId);
      }
    }
    for (final d in appointments) {
      final m = d.data;
      final id = '${m['patientId'] ?? ''}';
      final date = reportDate(m['date']);
      if (id.isEmpty ||
          date == null ||
          date.isAfter(now) ||
          date.isBefore(now.subtract(const Duration(days: 90))) ||
          '${m['status']}'.toLowerCase() != 'finalizado') {
        continue;
      }
      final previous = reportDate(visits[id]?['date']);
      if (previous == null || date.isAfter(previous)) {
        visits[id] = {'date': date, 'procedure': '${m['procedure'] ?? ''}'};
      }
    }
    return PatientListContext(
      debts: debts,
      treatments: treatments,
      budgets: budgets,
      attendance: visits,
    );
  }
}

class PatientListEntry {
  const PatientListEntry(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get name => '${data['name'] ?? 'Sem nome'}';
  String get phone => '${data['phone'] ?? ''}';
  String get cpf => '${data['cpf'] ?? ''}';
  String get record =>
      '${data['recordNumber'] ?? data['prontuario'] ?? data['medicalRecordNumber'] ?? ''}';
  String get status => '${data['status'] ?? 'Ativo'}';
  bool get active =>
      ['ativo', 'active', 'em tratamento'].contains(status.toLowerCase());
  bool get consent =>
      data['lgpdPortalConsent'] is Map &&
      (data['lgpdPortalConsent'] as Map)['accepted'] == true;
  DateTime? get created => reportDate(data['createdAt']);
  bool matches(String search) {
    final q = patientSearchKey(search.trim());
    if (q.isEmpty) return true;
    if (patientSearchKey('$name $phone $cpf $record $id').contains(q)) {
      return true;
    }
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 2 &&
        RegExp(r'^[\d\s+().\-]+$').hasMatch(q) &&
        ([
          phone,
          cpf,
          record,
        ].any((v) => v.replaceAll(RegExp(r'\D'), '').contains(digits)));
  }
}

List<PatientListEntry> filterPatientList(
  List<PatientListEntry> rows, {
  required PatientListContext context,
  String search = '',
  Set<PatientListFilter> filters = const {},
  PatientListSort sort = PatientListSort.alphabetic,
}) {
  final result = rows
      .where(
        (p) =>
            p.matches(search) &&
            (!filters.contains(PatientListFilter.noConsent) || !p.consent) &&
            (!filters.contains(PatientListFilter.debt) ||
                (context.debts[p.id] ?? 0) > 0) &&
            (!filters.contains(PatientListFilter.treatment) ||
                context.treatments.contains(p.id)) &&
            (!filters.contains(PatientListFilter.budget) ||
                context.budgets.contains(p.id)),
      )
      .toList();
  result.sort((a, b) {
    int order = 0;
    switch (sort) {
      case PatientListSort.alphabetic:
        break;
      case PatientListSort.recent:
        order = (b.created ?? DateTime(1970)).compareTo(
          a.created ?? DateTime(1970),
        );
        break;
      case PatientListSort.attendance:
        order =
            (reportDate(context.attendance[b.id]?['date']) ?? DateTime(1970))
                .compareTo(
                  reportDate(context.attendance[a.id]?['date']) ??
                      DateTime(1970),
                );
        break;
    }
    if (order != 0) return order;
    final name = patientSearchKey(a.name).compareTo(patientSearchKey(b.name));
    return name != 0 ? name : a.id.compareTo(b.id);
  });
  return result;
}

String patientMaskedCpf(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return raw.isEmpty ? '' : 'Não informado';
  return '${d.substring(0, 3)}.***.***-${d.substring(9)}';
}
