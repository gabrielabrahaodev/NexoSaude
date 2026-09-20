import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../ui/app_theme.dart';
import '../../../services/treatment_service.dart';
import '../../../services/patient_financial_oracle.dart';
import '../../../models/financial_model.dart'; 
import '../../../models/expense_model.dart';
import '../../../utils/display.dart';   

class TreatmentsTab extends StatefulWidget {
  final String patientName;
  final String patientId;

  const TreatmentsTab({
    super.key,
    required this.patientName,
    required this.patientId,
  });

  @override
  State<TreatmentsTab> createState() => _TreatmentsTabState();
}

class _TreatmentsTabState extends State<TreatmentsTab> {
  final TreatmentService _treatService = TreatmentService();
  final PatientFinancialOracle _oracle = PatientFinancialOracle();

  // Modal Atualizado: Mostra Lab e Comissão separados
  void _showLocalFinancialSummary(BuildContext context, double paid, double labCost, double commCost, double total) {
    double totalCost = labCost + commCost;
    double margin = total - totalCost; 
    double percent = total == 0 ? 0 : (margin / total) * 100;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Raio-X deste Tratamento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.grey),
              title: const Text("Valor do Contrato"),
              trailing: Text("${formatBRL(total)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.arrow_circle_up, color: Colors.green),
              title: const Text("Recebido do Paciente"),
              trailing: Text("${formatBRL(paid)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            ListTile(
              leading: const Icon(Icons.science, color: Colors.red),
              title: const Text("Custos Externos"),
              subtitle: const Text("Laboratórios e Materiais"),
              trailing: Text("- ${formatBRL(labCost)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.purple),
              title: const Text("Repasses/Comissões"),
              subtitle: const Text("Pagamento aos dentistas"),
              trailing: Text("- ${formatBRL(commCost)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.monetization_on, color: Colors.blue),
              title: const Text("Margem Líquida"),
              trailing: Text("${percent.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fechar"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.patientId.isEmpty) return const Center(child: Text("Erro ID."));

    return StreamBuilder<QuerySnapshot>(
      stream: _treatService.getPlansStream(widget.patientId),
      builder: (context, snapshot) {
        // --- ALTERAÇÃO 1: EXIBIR O ERRO REAL PARA DIAGNÓSTICO ---
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                "Erro técnico ao carregar: ${snapshot.error}",
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        // --------------------------------------------------------

        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                const Text("Nenhum plano iniciado."),
              ],
            ),
          );
        }

        return StreamBuilder<Map<String, dynamic>>(
          stream: _oracle.getPatientFinancialHealth(widget.patientId),
          builder: (context, finSnap) {
            
            final List<dynamic> fullTimeline = finSnap.hasData 
                ? (finSnap.data!['timeline'] as List<dynamic>) 
                : [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final String planId = doc.id;
                
                final status = data['status'] ?? 'active';
                
                // --- ALTERAÇÃO 2: PROTEÇÃO NA LISTA DE ITENS ---
                List<Map<String, dynamic>> items = [];
                if (data['items'] != null && data['items'] is List) {
                  items = (data['items'] as List).map((e) {
                    // Garante que é um Mapa, se não for (ex: String), cria um mapa simples
                    if (e is Map) return Map<String, dynamic>.from(e);
                    return {'name': e.toString(), 'price': 0, 'status': 'pendente'};
                  }).toList();
                }
                // ----------------------------------------------

                final startDate = (data['startDate'] as Timestamp).toDate();
                final double planTotal = (data['totalValue'] ?? 0.0).toDouble();

                // 1. Filtra Receitas deste Plano
                final planReceivables = fullTimeline.whereType<FinancialModel>().where((f) => f.planId == planId).toList();
                
                // 2. Extrai IDs das receitas para cruzar com as despesas
                final Set<String> planFinancialIds = planReceivables.map((f) => f.id).toSet();

                // 3. Filtra Despesas (Lógica Atualizada: Vínculo Direto OU Vínculo via Pagamento)
                final planExpenses = fullTimeline.whereType<ExpenseModel>().where((e) {
                  bool isDirectlyLinked = e.relatedPlanId == planId;
                  bool isLinkedToPayment = e.relatedFinancialId != null && planFinancialIds.contains(e.relatedFinancialId);
                  return isDirectlyLinked || isLinkedToPayment;
                });

                double localPaid = planReceivables
                    .where((f) =>
                        f.isPaid && f.status.toLowerCase() != 'cancelado')
                    .fold(0.0, (sum, f) => sum + f.amount);
                
                // Separa Custos e Comissões
                double localLabCost = planExpenses.where((e) => !e.isCommission).fold(0.0, (sum, e) => sum + e.amount);
                double localCommCost = planExpenses.where((e) => e.isCommission).fold(0.0, (sum, e) => sum + e.amount);
                
                double totalCost = localLabCost + localCommCost;
                double localMarginValue = planTotal - totalCost;
                double localPercent = planTotal == 0 ? 0 : (localMarginValue / planTotal) * 100;
                
                double progress = planTotal == 0 ? 0 : (localPaid / planTotal);
                if (progress > 1) progress = 1;

                final installmentsList = planReceivables.where((f) => f.installmentNumber != null && f.installmentNumber!.contains('/') && f.status.toLowerCase() != 'cancelado').toList();
                int totalInstallments = installmentsList.length;
                int paidInstallments = installmentsList.where((f) => f.isPaid).length;
                String installmentStatus = totalInstallments > 0 ? "$paidInstallments/$totalInstallments Pagas" : "";

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        decoration: BoxDecoration(
                          color: status == 'active' ? AppColors.surface : AppColors.background,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!))
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Iniciado em ${formatDateShortYear(startDate)}", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(status == 'active' ? "EM ANDAMENTO" : "CONCLUÍDO", style: TextStyle(fontWeight: FontWeight.bold, color: status == 'active' ? AppColors.primary : Colors.grey)),
                              ],
                            ),
                            InkWell(
                              onTap: () => _showLocalFinancialSummary(context, localPaid, localLabCost, localCommCost, planTotal),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: localPercent > 30 ? Colors.green[50] : Colors.orange[50], 
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: localPercent > 30 ? Colors.green : Colors.orange)
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.insights, size: 16, color: localPercent > 30 ? Colors.green : Colors.orange),
                                    const SizedBox(width: 6),
                                    Text("Margem: ${localPercent.toStringAsFixed(0)}%", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: localPercent > 30 ? Colors.green[800] : Colors.orange[800])),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final bool isDone = item['status'] == 'realizado';
                          return ListTile(
                            dense: true,
                            leading: Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? Colors.green : Colors.grey, size: 20),
                            title: Text(item['name'] ?? 'Procedimento', style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : null)),
                            trailing: Text("R\$ ${item['price']?.toString() ?? '0'}"),
                          );
                        },
                      ),
                      
                      const Divider(height: 1),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Progresso Financeiro", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                if (totalInstallments > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                                    child: Text(installmentStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${formatBRL(localPaid)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                Text("de ${formatBRL(planTotal)}", style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                            if (localLabCost > 0 || localCommCost > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    if (localLabCost > 0)
                                      Text("Custos: ${formatBRL(localLabCost)}  ", style: TextStyle(fontSize: 11, color: Colors.red[300], fontStyle: FontStyle.italic)),
                                    if (localCommCost > 0)
                                      Text("Repasses: ${formatBRL(localCommCost)}", style: TextStyle(fontSize: 11, color: Colors.purple[300], fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              )
                          ],
                        ),
                      ),
                      
                      if (status == 'active') ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Encerrar Tratamento?"), content: const Text("Concluir plano?"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Confirmar"))]));
                                if (confirm == true) await _treatService.closePlan(doc.id);
                              }, 
                              icon: const Icon(Icons.check, size: 18, color: Colors.orange), 
                              label: const Text("ENCERRAR TRATAMENTO", style: TextStyle(color: Colors.orange)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                            ),
                          ),
                        )
                      ]
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }
}