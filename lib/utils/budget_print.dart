import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/budget_model.dart';
import 'display.dart';
import 'report_export.dart' show reportMoney;

Future<Uint8List> budgetProposalPdf(
  List<BudgetModel> budgets,
  String clinic,
) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  for (final b in budgets) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'NexoSaúde • Proposta de Tratamento',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(budgetTitle(b)),
          pw.Text('Paciente: ${b.patientName}'),
          pw.Text('Unidade: $clinic'),
          pw.Text('Status: ${b.status}'),
          if (b.dateKnown) pw.Text('Emitido em ${formatDateFull(b.date)}'),
          if (budgetDate(b.details['validUntil']) != null)
            pw.Text(
              'Validade: ${formatDateFull(budgetDate(b.details['validUntil'])!)}',
            ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'Procedimento',
              'Dente / Região',
              'Qtd',
              'Unitário',
              'Desconto',
              'Subtotal',
            ],
            data: [
              for (final raw in b.items)
                [
                  BudgetItemDisplay(raw).name,
                  BudgetItemDisplay(raw).region,
                  '${BudgetItemDisplay(raw).quantity}',
                  reportMoney(BudgetItemDisplay(raw).unitPrice),
                  raw['discountAmount'] == null
                      ? 'Não informado'
                      : reportMoney(BudgetItemDisplay(raw).discount),
                  reportMoney(BudgetItemDisplay(raw).subtotal),
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'TOTAL: ${reportMoney(b.total)}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Condições: ${b.details['paymentConditions'] ?? 'Não informadas'}',
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Proposta comercial. A aprovação do orçamento confirma o tratamento e suas condições; este documento não é comprovante de pagamento.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
  return doc.save();
}

Future<void> printBudgetProposals(
  List<BudgetModel> budgets,
  String clinic, {
  bool Function()? stillValid,
}) async {
  if (budgets.isEmpty) return;
  final bytes = await budgetProposalPdf(budgets, clinic);
  if (stillValid != null && !stillValid()) throw StateError('Unidade alterada');
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'Proposta_Orcamento.pdf',
  );
}
