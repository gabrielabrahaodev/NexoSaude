import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../services/oracle_report_service.dart';
import 'display.dart';

String reportMoney(num value) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
const reportMonths = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
String reportMonthLabel(DateTime month) =>
    '${reportMonths[month.month - 1]} ${month.year}';
String reportText(Object? value, {String fallback = 'Não informado'}) =>
    value == null || value.toString().trim().isEmpty
    ? fallback
    : value.toString();
String reportDescription(TransactionItem t) => reportText(
  t.details['title'],
  fallback: reportText(t.details['description'], fallback: t.title),
);
String reportCategory(TransactionItem item) =>
    reportText(item.details['category'], fallback: item.category);
String reportMethod(TransactionItem item) =>
    reportText(item.details['paymentMethod'], fallback: 'Não informada');
double? reportNet(TransactionItem item) {
  final value = parseBRL(item.details['valorLiquido']);
  return value.isFinite && (value > 0 || item.amount == 0) ? value : null;
}

String reportCsv(OracleReportSnapshot snapshot) {
  String cell(Object? raw) {
    var s = '${raw ?? ''}';
    if (RegExp(r'^\s*[=+@\-]').hasMatch(s)) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  final rows = <List<Object?>>[
    [
      'Tipo',
      'Data efetiva',
      'Vencimento',
      'Paciente / Conta',
      'Descrição',
      'Profissional / Fornecedor',
      'Categoria',
      'Forma',
      'Status',
      'Valor bruto',
      'Líquido registrado',
      'Valor já pago',
    ],
    for (final t in snapshot.transactions)
      [
        t.isIncome ? 'Entrada' : 'Saída',
        formatDateFull(t.date),
        formatDateFull(t.dueDate),
        t.title,
        reportDescription(t),
        t.isIncome ? t.details['dentistName'] : t.details['supplierName'],
        reportCategory(t),
        reportMethod(t),
        t.details['status'],
        t.amount.toStringAsFixed(2).replaceAll('.', ','),
        reportNet(t)?.toStringAsFixed(2).replaceAll('.', ','),
        t.paidAmount.toStringAsFixed(2).replaceAll('.', ','),
      ],
  ];
  return '\uFEFF${rows.map((r) => r.map(cell).join(';')).join('\r\n')}';
}

void downloadReportCsv(DateTime month, OracleReportSnapshot snapshot) {
  final blob = html.Blob([reportCsv(snapshot)], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute(
      'download',
      'dre-${month.year}-${month.month.toString().padLeft(2, '0')}.csv',
    )
    ..click();
  html.Url.revokeObjectUrl(url);
}
