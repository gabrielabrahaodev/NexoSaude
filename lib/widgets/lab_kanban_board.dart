import 'package:flutter/material.dart';
import '../screens/lab/clinical_lab_view.dart';
import '../utils/lab_export.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/lab_service.dart';
import '../models/lab_order.dart';
import 'package:odonto_controle/utils/display.dart';

class LabKanbanBoard extends StatefulWidget {
  final List<LabOrderModel> orders;
  final LabService? service;
  final bool showPatientName;
  final VoidCallback onNew;
  final bool loading, creating;
  final String? error;

  const LabKanbanBoard({
    super.key,
    required this.orders,
    this.showPatientName = false,
    required this.onNew,
    this.loading = false,
    this.creating = false,
    this.error,
    this.service,
  });

  @override
  State<LabKanbanBoard> createState() => _LabKanbanBoardState();
}

class _LabKanbanBoardState extends State<LabKanbanBoard> {
  late final LabService _labService;
  @override
  void initState() {
    super.initState();
    _labService = widget.service ?? LabService();
  }

  // --- CONFIRMAÇÃO DE EXCLUSÃO ---
  void _confirmDelete(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Pedido"),
        content: const Text(
          "Excluir este pedido? Eventual conta a pagar será mantida em Relatórios → A Pagar.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _labService.deleteOrder(orderId);
                if (mounted) {
                  toast(
                    context,
                    "Pedido excluído. Eventual conta a pagar foi mantida.",
                  );
                }
              } catch (e) {
                if (mounted) {
                  toast(
                    context,
                    "Não foi possível excluir o pedido: $e",
                    error: true,
                  );
                }
              }
            },
            child: const Text("EXCLUIR"),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE MOVIMENTAÇÃO ---
  void _handleCardDrop(LabOrderModel order, String targetStatus) {
    // Se já estiver em um status equivalente, não faz nada
    if (order.status == targetStatus) return;
    // Se estiver em 'Solicitado' e o alvo for 'pending_send', considera igual (não move)
    if ((order.status == 'Solicitado' || order.status == 'pending_send') &&
        targetStatus == 'pending_send') {
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        DateTime selectedDate = DateTime.now();
        String title = "";

        if (targetStatus == 'sent') {
          title = "Confirmar Envio";
        } else if (targetStatus == 'pending_return') {
          title = "Previsão de Retorno";
        } else if (targetStatus == 'delivered') {
          title = "Confirmar Entrega";
        } else {
          title = "Mover para Aguardando";
        }

        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 320,
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Confirme a data do evento:"),
                    const SizedBox(height: 10),
                    Expanded(
                      child: CalendarDatePicker(
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        onDateChanged: (d) =>
                            setStateModal(() => selectedDate = d),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Map<String, dynamic> updateData = {};
                    if (targetStatus == 'sent') {
                      updateData['sentDate'] = selectedDate;
                    }
                    if (targetStatus == 'pending_return') {
                      updateData['returnDate'] = selectedDate;
                    }
                    if (targetStatus == 'delivered') {
                      updateData['deliveredDate'] = selectedDate;
                    }

                    if (targetStatus == 'pending_send') {
                      updateData['sentDate'] = null;
                      updateData['returnDate'] = null;
                      updateData['deliveredDate'] = null;
                    }

                    await _labService.updateStatus(
                      order.id,
                      targetStatus,
                      updateData,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text("Confirmar Mover"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ... (MÉTODOS DE INTERAÇÃO E DETALHES IGUAIS AO SEU CÓDIGO - OMITIDOS PARA BREVIDADE, MAS MANTENHA-OS) ...
  // [MANTENHA _showAddInteractionDialog, _showInteractionHistory, _showOrderDetails, _buildDetailRow, _formatRelativeDate, _getInitials AQUI]

  // --- REPLICAÇÃO DAS FUNÇÕES AUXILIARES PARA O CÓDIGO FUNCIONAR COMPLETO ---
  void _showAddInteractionDialog(String orderId) {
    final textCtrl = TextEditingController();
    bool isProblem = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text("Nova Interação"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Ex: Liguei cobrando...",
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                value: isProblem,
                title: const Text(
                  "Problema/Atraso",
                  style: TextStyle(fontSize: 14),
                ),
                onChanged: (v) => setStateModal(() => isProblem = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (textCtrl.text.isEmpty) return;
                String author = "Usuário";
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  author =
                      user.displayName ?? user.email?.split('@')[0] ?? "Staff";
                }
                await _labService.addInteraction(
                  orderId,
                  LabInteraction(
                    text: textCtrl.text,
                    date: DateTime.now(),
                    author: author,
                    isProblem: isProblem,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
  }

  void _showInteractionHistory(LabOrderModel order) {
    // (Mesma implementação do seu código anterior)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => FractionallySizedBox(
        heightFactor: 0.6,
        child: ListView(
          children: order.interactions
              .map(
                (i) => ListTile(
                  title: Text(i.text),
                  subtitle: Text(
                    "${i.author} - ${formatDateTimeShort(i.date)}",
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showOrderDetails(LabOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Detalhes do pedido',
                style: Theme.of(c).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(order.patientName),
              Text(order.description),
              const SizedBox(height: 12),
              Text('Laboratório: ${order.supplierName ?? 'Não informado'}'),
              Text('Solicitante: ${order.dentistName ?? 'Não informado'}'),
              Text('Tipo: ${order.workType ?? 'Não informado'}'),
              Text(
                'Custo: ${order.price > 0
                    ? formatLabMoney(order.price)
                    : order.hasCost == false
                    ? 'Sem custo'
                    : 'Não informado'}',
              ),
              if (order.costDueDate != null)
                Text('Vencimento: ${formatDateFull(order.costDueDate!)}'),
              if (order.relatedExpenseId != null)
                const Text('Conta a pagar disponível em Relatórios → A Pagar.'),
              Text('Status registrado: ${order.status}'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClinicalLabView(
    orders: widget.orders,
    individual: !widget.showPatientName,
    onNew: widget.onNew,
    creating: widget.creating,
    loading: widget.loading,
    error: widget.error,
    onExport: downloadLabCsv,
    onMove: _handleCardDrop,
    onAction: (order, action) {
      switch (action) {
        case 'delete':
          _confirmDelete(order.id);
        case 'history':
          _showInteractionHistory(order);
        case 'interaction':
          _showAddInteractionDialog(order.id);
        default:
          _showOrderDetails(order);
      }
    },
  );
}
