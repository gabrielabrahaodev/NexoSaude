import 'package:universal_html/html.dart' as html;
import '../models/collection_queue.dart';
import '../services/oracle_report_service.dart' show reportDate;
import 'display.dart';

String collectionCsv(
  DateTime month,
  List<CollectionCharge> rows,
  CollectionQueue snapshot,
) {
  String cell(Object? value) {
    var v = '${value ?? ''}';
    if (RegExp(r'^\s*[=+@\-]').hasMatch(v)) v = "'$v";
    return '"${v.replaceAll('"', '""')}"';
  }

  final data = <List<Object?>>[
    [
      'Competência',
      'Unidade',
      'Paciente',
      'Descrição',
      'Tipo',
      'Vencimento',
      'Valor',
      'Situação',
      'Próximo lembrete',
      'Contato hoje',
    ],
    for (final c in rows)
      [
        collectionPeriod(month),
        c.clinic.name,
        c.patientName,
        c.description,
        c.isPackage ? 'Pacote mensal' : 'Procedimento / sessão',
        c.dueDate == null ? '' : formatDateFull(c.dueDate!),
        c.issue == null ? c.amount.toStringAsFixed(2).replaceAll('.', ',') : '',
        c.issue ?? 'Em aberto',
        c.nextContact == null ? '' : c.nextContact!.toIso8601String(),
        c.contactedToday ? 'Sim' : 'Não',
      ],
    for (final d in snapshot.receipts)
      [
        collectionPeriod(month),
        snapshot.clinics
                .where((c) => c.id == d.data['clinicId'])
                .firstOrNull
                ?.name ??
            '',
        d.data['patientName'],
        d.data['title'] ?? d.data['description'],
        'Recebimento',
        reportDate(d.data['dueDate']) == null
            ? ''
            : formatDateFull(reportDate(d.data['dueDate'])!),
        d.data['amount'],
        'Liquidado',
        '',
        '',
      ],
    [],
    ['Total em aberto da unidade', snapshot.pending],
    ['Liquidado no mês', snapshot.settled],
    ['Contatos confirmados na competência da fila', snapshot.contacts],
  ];
  return '\uFEFF${data.map((r) => r.map(cell).join(';')).join('\r\n')}';
}

void downloadCollectionsCsv(
  DateTime month,
  List<CollectionCharge> rows,
  CollectionQueue snapshot,
) {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob([collectionCsv(month, rows, snapshot)], 'text/csv;charset=utf-8'),
  );
  html.AnchorElement(href: url)
    ..setAttribute('download', 'cobrancas-${collectionPeriod(month)}.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}
