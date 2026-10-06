import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

import 'package:csv/csv.dart'; 
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:open_file/open_file.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:universal_html/html.dart' as html; 

import '../../services/oracle_report_service.dart';
import '../../services/payment_service.dart';
import '../../utils/display.dart';
import '../../widgets/page_header.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  final OracleReportService _service = OracleReportService();
  final PaymentService _paymentService = PaymentService(); 
  DateTime _currentMonth = DateTime.now();

  /// Filtro da lista (totais do mês não mudam).
  FlowFilter _filter = FlowFilter.todos;

  void _changeMonth(int monthsToAdd) {
    setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + monthsToAdd, 1));
  }

  // --- GERAR PDF COM DADOS COMPLETOS ---
  Future<void> _generateAndSavePDF(List<dynamic> transactions, OracleReportSnapshot summary) async {
    // 1. Mostrar loading (pois vamos buscar dados no banco)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // A. Buscar Dados do Profissional (Usuário Logado)
      final user = FirebaseAuth.instance.currentUser;
      String profName = "Profissional de Saúde";
      String profDoc = ""; // CPF/CNPJ
      String profReg = ""; // CRM/CRO
      String profAddress = ""; 
      
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          profName = userData['name'] ?? profName;
          profDoc = userData['cpf'] ?? userData['cnpj'] ?? "";
          profReg = userData['professionalRegister'] ?? ""; // Ex: CRO 12345
          profAddress = userData['address'] ?? "";
        }
      }

      // B. Preparar Dados da Tabela (Buscando CPF dos pacientes)
      List<List<String>> tableData = [
        ['Data', 'CPF Paciente', 'Nome Paciente', 'Serviço/Descrição', 'Pagamento', 'Valor']
      ];

      double calcIncome = 0;
      double calcExpense = 0;

      // Iterar e buscar CPF de cada paciente
      for (var item in transactions) {
        if (item.isIncome) calcIncome += item.amount; else calcExpense += item.amount;

        // Se for receita e tiver ID de paciente, busca o CPF
        String patientCpf = "";
        if (item.isIncome && item.patientId != null) {
          try {
            final patDoc = await FirebaseFirestore.instance.collection('patients').doc(item.patientId).get();
            if (patDoc.exists) {
              patientCpf = patDoc.data()?['cpf'] ?? "";
            }
          } catch (e) { /* ignore erro de busca */ }
        }

        tableData.add([
          formatDateShort(item.date),
          patientCpf.isEmpty ? "---" : patientCpf,
          item.title, // Nome do Paciente
          item.isIncome ? "Consulta/Procedimento" : item.category, // Descrição
          item.paymentMethod, // Dinheiro, Cartão, etc
          "${formatBRL(item.amount)}"
        ]);
      }

      Navigator.pop(context); // Fecha loading

      // C. Desenhar o PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // 1. Dados do Profissional
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(), borderRadius: pw.BorderRadius.circular(4)),
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("EMITENTE / PROFISSIONAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Divider(thickness: 0.5),
                    pw.Text("Nome: $profName", style: const pw.TextStyle(fontSize: 12)),
                    pw.Row(children: [
                      pw.Text("CPF/CNPJ: $profDoc", style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(width: 20),
                      pw.Text("Registro: $profReg", style: const pw.TextStyle(fontSize: 10)),
                    ]),
                    pw.Text("Endereço: $profAddress", style: const pw.TextStyle(fontSize: 10)),
                  ]
                )
              ),
              
              pw.SizedBox(height: 10),
              
              pw.Text(
                "RELATÓRIO DE PRESTAÇÃO DE SERVIÇOS DE SAÚDE - ${DateFormat('MMMM/yyyy', 'pt_BR').format(_currentMonth).toUpperCase()}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                textAlign: pw.TextAlign.center
              ),
              
              pw.SizedBox(height: 15),

              // 2. Dados dos Serviços (Tabela)
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(40), // Data
                  1: const pw.FixedColumnWidth(70), // CPF
                  2: const pw.FlexColumnWidth(2),   // Nome
                  3: const pw.FlexColumnWidth(2),   // Descrição
                  4: const pw.FixedColumnWidth(60), // Pagto
                  5: const pw.FixedColumnWidth(60), // Valor
                },
                data: tableData,
              ),

              pw.SizedBox(height: 10),

              // 3. Totais
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Total de Receitas: ${formatBRL(calcIncome)}", style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Total de Despesas: ${formatBRL(calcExpense)}", style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Resultado Líquido: ${formatBRL(summary.netProfit)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ]
                )
              ),
              
              pw.SizedBox(height: 20),
              pw.Text("Este documento serve como base para escrituração do Livro Caixa/Carnê-Leão.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ];
          },
        ),
      );

      String fileName = "Relatorio_Saude_${DateFormat('MM_yyyy').format(_currentMonth)}.pdf";

      if (kIsWeb) {
        await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
      } else {
        await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
      }
      
      _showSuccess("Relatório detalhado gerado com sucesso!");

    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.pop(context); // Tira loading
      _showError("Erro ao gerar PDF: $e");
    }
  }

  // --- GERAR EXCEL (CSV) ---
  Future<void> _generateAndSaveCSV(List<dynamic> transactions) async {
    try {
      List<List<dynamic>> rows = [];
      rows.add(["Data", "Nome Paciente", "Categoria", "Forma Pagamento", "Tipo", "Valor (R\$)", "Status"]);

      for (var item in transactions) {
        rows.add([
          formatDateFull(item.date),
          item.title,
          item.category,
          item.paymentMethod,
          item.isIncome ? "Receita" : "Despesa",
          item.amount.toStringAsFixed(2).replaceAll('.', ','),
          item.isPaid ? "Pago" : "Pendente"
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      String fileName = "Relatorio_Financeiro_${DateFormat('MM_yyyy').format(_currentMonth)}.csv";

      if (kIsWeb) {
        final bytes =  Uint8List.fromList(csvData.codeUnits);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
        html.Url.revokeObjectUrl(url);
        _showSuccess("Arquivo Excel baixado!");
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/$fileName";
        final file = File(path);
        await file.writeAsString(csvData);
        await OpenFile.open(path);
        _showSuccess("Salvo em: $path");
      }
    } catch (e) {
      _showError("Erro ao gerar Excel: $e");
    }
  }

  void _showSuccess(String msg) {
    if(!mounted) return;
    toast(context, msg, ok: true);
  }

  void _showError(String msg) {
    if(!mounted) return;
    toast(context, msg, error: true);
  }

  // --- DIÁLOGO DE EXPORTAÇÃO ---
  void _exportReceitaSaude(List<dynamic> transactions, OracleReportSnapshot summary) {
    if (transactions.isEmpty) {
      _showError("Não há dados para gerar relatório neste mês.");
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.assignment_turned_in, color: Colors.blue),
            SizedBox(width: 10),
            Text("Relatório Fiscal"),
          ],
        ),
        content: const Text("Selecione o formato. O PDF incluirá os dados do profissional e CPF dos pacientes."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.table_view, size: 18),
            label: const Text("EXCEL"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _generateAndSaveCSV(transactions);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text("PDF COMPLETO"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _generateAndSavePDF(transactions, summary);
            },
          ),
        ],
      ),
    );
  }

  // --- FUNÇÃO DE ESTORNO ---
  void _confirmReversal(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Estornar Lançamento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Deseja cancelar o pagamento de:\n${item.title}?"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
              child: const Text("O valor voltará a ficar PENDENTE.", style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              try {
                await _paymentService.reverseTransaction(item.id, item.isIncome);
                if (mounted) _showSuccess("Estorno realizado!");
              } catch (e) {
                if (mounted) _showError("Erro ao estornar: $e");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("CONFIRMAR"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Fluxo de Caixa Real", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        centerTitle: true,
      ),
      // Imprimir fica no canto inferior (antes cobria a seta do mês).
      body: StreamBuilder<OracleReportSnapshot>(
        stream: _service.getMonthOverview(_currentMonth),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!;
          final transactions = data.transactions;

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: MonthSelectorPill(
                      date: _currentMonth,
                      labelBelow:
                          "Saldo Realizado: ${formatBRL(data.netProfit)}",
                      labelBelowStyle: TextStyle(
                          color: data.netProfit >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      onPrev: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final entry in {
                          FlowFilter.todos: 'Todos',
                          FlowFilter.recebido: 'Recebido',
                          FlowFilter.aReceber: 'A Receber',
                          FlowFilter.inadimplente: 'Inadimplente',
                        }.entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            onSelected: (_) => setState(
                                () => _filter = entry.key),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Builder(builder: (context) {
                      final visible = flowFilter(
                          transactions, _filter, DateTime.now());
                      if (transactions.isEmpty)
                        return const Center(child: Text("Nenhuma movimentação neste mês.", style: TextStyle(color: Colors.grey)));
                      if (visible.isEmpty)
                        return const Center(child: Text("Nada neste filtro.", style: TextStyle(color: Colors.grey)));
                      return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            return _TransactionRow(
                              item: item, 
                              onLongPress: item.isPaid ? () => _confirmReversal(item) : null
                            );
                          },
                        );
                    }),
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.small(
                  backgroundColor: AppColors.surface,
                  tooltip: "Imprimir",
                  child: const Icon(Icons.print, color: Colors.blueGrey),
                  onPressed: () =>
                      _exportReceitaSaude(transactions, data),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onLongPress; 

  const _TransactionRow({required this.item, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    // Inadimplente = pendente vencido (mesma regra do filtro).
    final overdue = isOverdueTx(item, DateTime.now());
    // DETERMINAÇÃO DE CORES (Lógica Anti-Erro)
    Color statusColor = Colors.grey;
    if (item.isIncome) {
      statusColor =
          item.isPaid ? Colors.green : (overdue ? Colors.red : Colors.orange);
    } else {
      statusColor =
          item.isPaid ? Colors.red : (overdue ? Colors.red : Colors.orange);
    }

    return InkWell(
      onLongPress: onLongPress, 
      onTap: onLongPress != null ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pressione e segure para estornar."), duration: Duration(milliseconds: 1500))) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface, 
          borderRadius: BorderRadius.circular(10), 
          border: Border(left: BorderSide(color: statusColor, width: 4)), 
          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))]
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('dd').format(item.date), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
                  Text(DateFormat('MMM').format(item.date).toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)), 
                        child: Text(item.category, style: TextStyle(fontSize: 10, color: AppColors.textSecondary))
                      ),
                      const SizedBox(width: 8),
                      // NOVA LÓGICA DE TAGS DE STATUS (Reconhece a Antecipação e evita o erro do ícone)
                      if (overdue)
                        const Text("INADIMPLENTE", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))
                      else if (item.isIncome && item.isPaid)
                        const Text("RECEBIDO", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold))
                      else if (item.isIncome && !item.isPaid)
                        const Text("PENDENTE", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))
                      else if (!item.isIncome && item.isPaid)
                        const Text("PAGO", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))
                      else
                        const Text("A PAGAR", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${item.isIncome ? '+' : '-'} ${formatBRL(item.amount)}", style: TextStyle(fontWeight: FontWeight.bold, color: item.isIncome ? Colors.green[700] : Colors.red[700], fontSize: 15)),
                const SizedBox(height: 2),
                Text("Saldo: ${formatBRL(item.runningBalance)}", style: TextStyle(fontSize: 10, color: Colors.grey[400]))
              ],
            )
          ],
        ),
      ),
    );
  }
}