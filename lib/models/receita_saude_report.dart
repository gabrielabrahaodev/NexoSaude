import 'financial_model.dart';
import 'patient_registration.dart';
import '../services/oracle_report_service.dart'
    show ReportDocument, reportDate, reportCanceled, reportAnticipated;
import '../utils/display.dart';

/// Draft for review/export only. It is never an official issued receipt.
class ReceitaSaudeLine {
  ReceitaSaudeLine({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.professionalId,
    required this.professionalName,
    required this.amount,
    required this.description,
    this.paymentDate,
    this.payerCpf = '',
    this.beneficiaryCpf = '',
  });
  final String id, patientId, patientName, professionalId, professionalName;
  double amount;
  String description, payerCpf, beneficiaryCpf;
  DateTime? paymentDate;
  bool selected = true;
  String get professionalKey => professionalId.isNotEmpty
      ? 'id:$professionalId'
      : professionalName.isNotEmpty
      ? 'name:$professionalName'
      : 'unassigned';
  List<String> issues(DateTime month) => [
    if (!PatientRegistrationDraft.validCpf(beneficiaryCpf))
      'CPF do beneficiário inválido ou ausente',
    if (!PatientRegistrationDraft.validCpf(payerCpf))
      'CPF do pagador inválido ou ausente',
    if (paymentDate == null) 'Data efetiva do pagamento ausente',
    if (paymentDate != null &&
        (paymentDate!.year != month.year || paymentDate!.month != month.month))
      'Pagamento fora do mês selecionado',
    if (!amount.isFinite || amount <= 0 || amount > 99999999999.99)
      'Valor fora do limite permitido',
  ];
}

class ReceitaSaudeExport {
  const ReceitaSaudeExport({
    required this.rows,
    required this.professionalName,
    required this.professionalCpf,
    required this.registration,
    required this.occupation,
    required this.pdf,
  });
  final List<ReceitaSaudeLine> rows;
  final String professionalName, professionalCpf, registration, occupation;
  final bool pdf;
}

String receitaCpf(String value) => value.replaceAll(RegExp(r'\D'), '');
const receitaOccupations = {
  '225': 'Médico',
  '226': 'Odontólogo',
  '230': 'Fonoaudiólogo',
  '231': 'Fisioterapeuta',
  '232': 'Terapeuta ocupacional',
  '255': 'Psicólogo',
};

/// Actual patient payment date, independent from credit settlement/anticipation.
DateTime? receitaPaymentDate(Map<String, dynamic> data) =>
    reportDate(data['paymentDate']) ??
    (reportAnticipated(data) ? null : reportDate(data['paidDate']));

List<ReceitaSaudeLine> receitaSaudeLines(
  DateTime month,
  List<ReportDocument> documents,
) {
  final unique = {for (final d in documents) d.id: d};
  final groups = <String, List<ReportDocument>>{};
  for (final d in unique.values) {
    final data = d.data;
    if ((data['type'] ?? 'income') != 'income' || reportCanceled(data)) {
      continue;
    }
    final paid =
        data['isPaid'] == true ||
        FinancialModel.isPaidOf(
          status: '${data['status'] ?? ''}',
          paidAmount: data['paidAmount'],
          amount: data['amount'],
        );
    if (!paid) {
      continue; // pending parents of partial payments are represented by their paid children.
    }
    final actual = receitaPaymentDate(data);
    if (actual != null &&
        (actual.year != month.year || actual.month != month.month)) {
      continue;
    }
    final key =
        data['isPartialAnticipation'] == true &&
            '${data['originalDocId'] ?? ''}'.isNotEmpty
        ? '${data['originalDocId']}'
        : d.id;
    groups.putIfAbsent(key, () => []).add(d);
  }
  return [
    for (final group in groups.entries) _fromGroup(group.key, group.value),
  ]..sort((a, b) => (a.paymentDate ?? month).compareTo(b.paymentDate ?? month));
}

ReceitaSaudeLine _fromGroup(String id, List<ReportDocument> group) {
  final main = group.where((d) => d.id == id).firstOrNull ?? group.first;
  final data = main.data;
  final title = '${data['title'] ?? ''}'.trim();
  return ReceitaSaudeLine(
    id: id,
    patientId: '${data['patientId'] ?? ''}',
    patientName: '${data['patientName'] ?? 'Sem paciente vinculado'}',
    professionalId: '${data['dentistId'] ?? ''}',
    professionalName: '${data['dentistName'] ?? ''}',
    amount: group.fold<double>(0, (v, d) => v + parseBRL(d.data['amount'])),
    description: title.isNotEmpty
        ? '$title${data['installmentNumber'] == null ? '' : ' - Parcela ${data['installmentNumber']}'}'
        : '${data['description'] ?? ''}',
    paymentDate: receitaPaymentDate(data),
    payerCpf: '${data['payerCpf'] ?? ''}',
    beneficiaryCpf: '${data['beneficiaryCpf'] ?? ''}',
  );
}

/// Receita Federal layout, 16 fields, semicolon, no headings, one professional/year.
String receitaSaudeCsv({
  required DateTime month,
  required List<ReceitaSaudeLine> rows,
  required String professionalCpf,
  required String occupation,
  required String registration,
}) {
  final selected = rows.where((r) => r.selected).toList();
  if (!PatientRegistrationDraft.validCpf(professionalCpf) ||
      !receitaOccupations.containsKey(occupation) ||
      registration.trim().length > 15 ||
      RegExp(r'[;\r\n"]').hasMatch(registration)) {
    throw ArgumentError('Confira CPF, ocupação e registro profissional.');
  }
  if (selected.isEmpty ||
      selected.length > 1000 ||
      selected.map((r) => r.professionalKey).toSet().length != 1 ||
      selected.any((r) => r.issues(month).isNotEmpty)) {
    throw ArgumentError(
      'Selecione até 1000 pagamentos válidos de um único profissional.',
    );
  }
  String safe(String text) {
    var s = text
        .replaceAll(RegExp(r'[\r\n;]'), ' ')
        .replaceAll('"', "'")
        .trim();
    if (RegExp(r'^[=+@\-]').hasMatch(s)) s = "'$s";
    return String.fromCharCodes(s.runes.take(255));
  }

  return selected
      .map(
        (r) => [
          formatDateFull(r.paymentDate!),
          'R01.001.001',
          occupation,
          r.amount.toStringAsFixed(2).replaceAll('.', ','),
          '',
          safe(r.description),
          'PF',
          receitaCpf(r.payerCpf),
          receitaCpf(r.beneficiaryCpf),
          '',
          '',
          '',
          '',
          'S',
          receitaCpf(professionalCpf),
          registration.trim(),
        ].join(';'),
      )
      .join('\r\n');
}
