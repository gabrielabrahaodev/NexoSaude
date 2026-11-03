import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import '../models/receita_saude_report.dart';
import 'display.dart';
import 'report_export.dart';

Future<Uint8List> receitaSaudePdf(
  DateTime month,
  String clinic,
  ReceitaSaudeExport data,
) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: font,
      italic: font,
      boldItalic: font,
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        pw.Text(
          'Receita Saúde',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Relatório de apoio à emissão - não é recibo oficial nem comprovante de envio à Receita Federal.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 10),
        pw.Text('$clinic - ${reportMonthLabel(month)}'),
        pw.Text(
          'Profissional: ${data.professionalName} | CPF: ${data.professionalCpf.isEmpty ? 'Não informado' : data.professionalCpf}',
        ),
        pw.Text(
          'Ocupação: ${data.occupation} - ${receitaOccupations[data.occupation]} | Registro: ${data.registration.isEmpty ? 'Não informado' : data.registration}',
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: [
            'Pagamento',
            'Paciente / serviço',
            'CPF beneficiário',
            'CPF pagador',
            'Valor recebido',
            'Pendências',
          ],
          data: [
            for (final row in data.rows)
              [
                row.paymentDate == null
                    ? 'Não informada'
                    : formatDateFull(row.paymentDate!),
                '${row.patientName}\n${row.description}',
                row.beneficiaryCpf.isEmpty
                    ? 'Não informado'
                    : row.beneficiaryCpf,
                row.payerCpf.isEmpty ? 'Não informado' : row.payerCpf,
                reportMoney(row.amount),
                row.issues(month).isEmpty
                    ? 'Sem pendências nos campos do pagamento'
                    : row.issues(month).join('; '),
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Total de pagamentos selecionados: ${reportMoney(data.rows.fold<double>(0, (sum, r) => sum + r.amount))}',
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Conferir CPF, ocupação e registro do prestador e pagamentos já emitidos antes de importar. Este relatório não comprova regularidade de registro profissional.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> downloadReceitaSaude(
  DateTime month,
  String clinic,
  ReceitaSaudeExport data, {
  bool Function()? stillValid,
}) async {
  final Uint8List bytes;
  if (data.pdf) {
    bytes = await receitaSaudePdf(month, clinic, data);
  } else {
    bytes = Uint8List.fromList(
      utf8.encode(
        receitaSaudeCsv(
          month: month,
          rows: data.rows,
          professionalCpf: data.professionalCpf,
          occupation: data.occupation,
          registration: data.registration,
        ),
      ),
    );
  }
  if (stillValid != null && !stillValid()) throw StateError('Unidade alterada');
  final blob = html.Blob([
    bytes,
  ], data.pdf ? 'application/pdf' : 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute(
      'download',
      'receita-saude-${month.year}-${month.month.toString().padLeft(2, '0')}.${data.pdf ? 'pdf' : 'csv'}',
    )
    ..click();
  html.Url.revokeObjectUrl(url);
}
