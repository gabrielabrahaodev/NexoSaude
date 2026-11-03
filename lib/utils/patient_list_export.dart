import 'package:universal_html/html.dart' as html;
import '../models/patient_list_entry.dart';
import '../services/oracle_report_service.dart' show reportDate;
import 'display.dart';

String patientListCsv(
  List<PatientListEntry> rows,
  PatientListContext? context,
) {
  String cell(Object? raw) {
    var s = '${raw ?? ''}';
    if (RegExp(r'^\s*[=+@\-]').hasMatch(s)) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  final table = <List<Object?>>[
    [
      'Nome',
      'Prontuário cadastrado',
      'Telefone',
      'CPF',
      'Situação',
      'Aceite LGPD',
      'Pendência financeira',
      'Tratamento em andamento',
      'Orçamento aberto',
      'Último atendimento (90 dias)',
    ],
    for (final p in rows)
      [
        p.name,
        p.record,
        p.phone,
        p.cpf,
        p.status,
        p.consent ? 'Sim' : 'Não',
        context == null
            ? ''
            : (context.debts[p.id] ?? 0)
                  .toStringAsFixed(2)
                  .replaceAll('.', ','),
        context == null
            ? ''
            : context.treatments.contains(p.id)
            ? 'Sim'
            : 'Não',
        context == null
            ? ''
            : context.budgets.contains(p.id)
            ? 'Sim'
            : 'Não',
        reportDate(context?.attendance[p.id]?['date']) == null
            ? ''
            : formatDateFull(reportDate(context!.attendance[p.id]!['date'])!),
      ],
  ];
  return '\uFEFF${table.map((r) => r.map(cell).join(';')).join('\r\n')}';
}

void downloadPatientList(
  List<PatientListEntry> rows,
  PatientListContext? context,
) {
  final blob = html.Blob([
    patientListCsv(rows, context),
  ], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'pacientes.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}
