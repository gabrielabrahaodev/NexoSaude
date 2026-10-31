import 'package:universal_html/html.dart' as html;
import '../models/lab_order.dart';
import 'display.dart';

String buildLabCsv(List<LabOrderModel> orders) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^\s*[=+@\-]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<Object?>>[
    [
      'Pedido',
      'Paciente',
      'Descrição',
      'Tipo',
      'Solicitante',
      'Laboratório',
      'Custo',
      'Status',
      'Previsão',
      'Conta a pagar',
    ],
    for (final o in orders)
      [
        o.id,
        o.patientName,
        o.description,
        o.workType,
        o.dentistName,
        o.supplierName,
        o.price.toStringAsFixed(2).replaceAll('.', ','),
        o.status,
        o.deliveryDate == null ? '' : formatDateFull(o.deliveryDate!),
        o.relatedExpenseId,
      ],
  ];
  return '\uFEFF${rows.map((r) => r.map(cell).join(';')).join('\r\n')}';
}

void downloadLabCsv(List<LabOrderModel> orders) {
  final blob = html.Blob([buildLabCsv(orders)], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'laboratorio.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}
