import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odonto_controle/models/lab_order.dart';
import '../services/lab_service.dart';
import '../models/lab_order.dart';

class LabKanbanBoard extends StatefulWidget {
  final List<LabOrderModel> orders;
  final bool showPatientName; 

  const LabKanbanBoard({
    super.key,
    required this.orders,
    this.showPatientName = false,
  });

  @override
  State<LabKanbanBoard> createState() => _LabKanbanBoardState();
}

class _LabKanbanBoardState extends State<LabKanbanBoard> {
  final LabService _labService = LabService();

  // --- CONFIRMAÇÃO DE EXCLUSÃO ---
  void _confirmDelete(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Pedido"),
        content: const Text("Tem certeza que deseja excluir este pedido de laboratório?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _labService.deleteOrder(orderId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido excluído.")));
              }
            },
            child: const Text("EXCLUIR"),
          )
        ],
      )
    );
  }

  // --- LÓGICA DE MOVIMENTAÇÃO ---
  void _handleCardDrop(LabOrderModel order, String targetStatus) {
    // Se já estiver em um status equivalente, não faz nada
    if (order.status == targetStatus) return;
    // Se estiver em 'Solicitado' e o alvo for 'pending_send', considera igual (não move)
    if ((order.status == 'Solicitado' || order.status == 'pending_send') && targetStatus == 'pending_send') return;

    showDialog(
      context: context,
      builder: (ctx) {
        DateTime selectedDate = DateTime.now();
        String title = "";
        
        if (targetStatus == 'sent') title = "Confirmar Envio";
        else if (targetStatus == 'pending_return') title = "Previsão de Retorno";
        else if (targetStatus == 'delivered') title = "Confirmar Entrega";
        else title = "Mover para Aguardando";

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
                        onDateChanged: (d) => setStateModal(() => selectedDate = d),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    Map<String, dynamic> updateData = {};
                    if (targetStatus == 'sent') updateData['sentDate'] = selectedDate;
                    if (targetStatus == 'pending_return') updateData['returnDate'] = selectedDate;
                    if (targetStatus == 'delivered') updateData['deliveredDate'] = selectedDate;

                    if (targetStatus == 'pending_send') {
                       updateData['sentDate'] = null;
                       updateData['returnDate'] = null;
                       updateData['deliveredDate'] = null;
                    }

                    await _labService.updateStatus(order.id, targetStatus, updateData);
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text("Confirmar Mover"),
                )
              ],
            );
          }
        );
      }
    );
  }

  // ... (MÉTODOS DE INTERAÇÃO E DETALHES IGUAIS AO SEU CÓDIGO - OMITIDOS PARA BREVIDADE, MAS MANTENHA-OS) ...
  // [MANTENHA _showAddInteractionDialog, _showInteractionHistory, _showOrderDetails, _buildDetailRow, _formatRelativeDate, _getInitials AQUI]
  
  // --- REPLICAÇÃO DAS FUNÇÕES AUXILIARES PARA O CÓDIGO FUNCIONAR COMPLETO ---
  void _showAddInteractionDialog(String orderId) {
    final textCtrl = TextEditingController();
    bool isProblem = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateModal) => AlertDialog(
      title: const Text("Nova Interação"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: textCtrl, maxLines: 3, decoration: const InputDecoration(hintText: "Ex: Liguei cobrando...", border: OutlineInputBorder())),
        CheckboxListTile(value: isProblem, title: const Text("Problema/Atraso", style: TextStyle(fontSize: 14)), onChanged: (v) => setStateModal(() => isProblem = v!))
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () async {
          if (textCtrl.text.isEmpty) return;
          String author = "Usuário";
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) author = user.displayName ?? user.email?.split('@')[0] ?? "Staff";
          await _labService.addInteraction(orderId, LabInteraction(text: textCtrl.text, date: DateTime.now(), author: author, isProblem: isProblem));
          if (mounted) Navigator.pop(ctx);
        }, child: const Text("Salvar"))
      ]
    )));
  }

  void _showInteractionHistory(LabOrderModel order) {
    // (Mesma implementação do seu código anterior)
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => FractionallySizedBox(heightFactor: 0.6, child: ListView(children: order.interactions.map((i) => ListTile(title: Text(i.text), subtitle: Text("${i.author} - ${DateFormat('dd/MM HH:mm').format(i.date)}"))).toList())));
  }

  void _showOrderDetails(LabOrderModel order) {
    // (Mesma implementação básica)
    showModalBottomSheet(context: context, builder: (c) => Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(order.procedureName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 10), Text(order.description)])));
  }

  String _formatRelativeDate(DateTime date) => DateFormat('dd/MM').format(date);
  String _getInitials(String name) => name.isNotEmpty ? name[0].toUpperCase() : "?";

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 10),
            const Text("Nenhum pedido de laboratório.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double availableHeight = constraints.maxHeight; 
        
        double minColumnWidth = 280.0;
        double totalSpacing = 80.0;
        double idealWidth = (availableWidth - totalSpacing) / 4;
        double finalColumnWidth = idealWidth < minColumnWidth ? minColumnWidth : idealWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), 
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // COLUNA 1: Aceita 'pending_send' E 'Solicitado'
              _buildKanbanColumn("Aguardando Envio", ["pending_send", "Solicitado"], "pending_send", Colors.orange, finalColumnWidth, availableHeight),
              
              // COLUNA 2: Aceita 'sent' E 'Enviado'
              _buildKanbanColumn("Enviado (No Lab)", ["sent", "Enviado"], "sent", Colors.blue, finalColumnWidth, availableHeight),
              
              // COLUNA 3
              _buildKanbanColumn("Aguardando Retorno", ["pending_return"], "pending_return", Colors.purple, finalColumnWidth, availableHeight),
              
              // COLUNA 4: Aceita 'delivered', 'Concluído', 'Entregue'
              _buildKanbanColumn("Entregue", ["delivered", "Concluído", "Entregue"], "delivered", Colors.green, finalColumnWidth, availableHeight),
            ],
          ),
        );
      }
    );
  }

  // --- ALTERAÇÃO AQUI: 'validStatuses' é uma Lista ---
  Widget _buildKanbanColumn(String title, List<String> validStatuses, String targetStatusKey, MaterialColor color, double width, double height) {
    
    // Filtra os itens que correspondem a QUALQUER status da lista
    final items = widget.orders.where((o) => validStatuses.contains(o.status)).toList();

    return DragTarget<LabOrderModel>(
      onWillAccept: (data) => data != null && !validStatuses.contains(data.status),
      onAccept: (order) => _handleCardDrop(order, targetStatusKey), 
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Container(
          width: width,
          height: height > 100 ? height - 32 : 500, 
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isHovering ? color[50] : Colors.grey[50], 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isHovering ? color : Colors.grey[200]!, width: isHovering ? 2 : 1)
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: color[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color[800]), overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Text("${items.length}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color[800])),
                    )
                  ],
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildDraggableCard(items[index], color, width);
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableCard(LabOrderModel order, MaterialColor color, double columnWidth) {
    DateTime? relevantDate;
    bool isOverdue = false;
    
    if (order.status == 'sent') relevantDate = order.sentDate;
    if (order.status == 'pending_return') {
      relevantDate = order.returnDate;
      if (relevantDate != null && relevantDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        isOverdue = true;
      }
    }
    if (order.status == 'delivered') relevantDate = order.deliveredDate;

    // A MÁGICA 1: Resgata a última interação com BLINDAGEM MÁXIMA contra pedidos antigos
    dynamic lastInteraction;
    try {
      // O '?.isNotEmpty == true' garante que se a lista for nula, ele não quebra!
      if (order.interactions?.isNotEmpty == true) {
        lastInteraction = order.interactions!.last;
      }
    } catch (e) {
      // Se o modelo corromper ao tentar ler a lista, o sistema ignora e segue a vida
      lastInteraction = null;
    }

    Widget buildCardContent({required bool isInteractive}) {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isInteractive ? () => _showOrderDetails(order) : null,
          splashColor: color.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOPO (Nome do Procedimento e Botão Excluir)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined, size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Expanded(child: Text(order.procedureName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))
                        ]
                      )
                    ),
                    if (isInteractive) 
                      SizedBox(width: 20, height: 20, child: PopupMenuButton<String>(padding: EdgeInsets.zero, icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey), onSelected: (val) { if (val == 'delete') _confirmDelete(order.id); }, itemBuilder: (c) => [const PopupMenuItem(value: 'delete', child: Text('Excluir'))]))
                  ],
                ),
                
                // 2. NOME DO PACIENTE
                if (widget.showPatientName) ...[
                  const SizedBox(height: 6),
                  Text(order.patientName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.blueGrey)),
                ],
                
                const SizedBox(height: 10),
                
                // 3. MEIO (Badge do Laboratório + Dentista + Descrição)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // A MÁGICA 2: O Badge Premium do Laboratório
                          if (order.supplierName != null && order.supplierName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.indigo[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.indigo[100]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.science, size: 10, color: Colors.indigo[400]),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(order.supplierName!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            
                          const SizedBox(height: 6),
                          
                          // DENTISTA
                          if (order.dentistName != null && order.dentistName!.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(child: Text(order.dentistName!, style: TextStyle(fontSize: 10, color: Colors.blueGrey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // DESCRIÇÃO
                    Expanded(
                      flex: 4, 
                      child: Text(order.description, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis)
                    )
                  ],
                ),
                
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 8),
                
                // 4. RODAPÉ (Data + Mini-Balão de Interação)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // DATA (Esquerda)
                    if (relevantDate != null) 
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 10, color: isOverdue ? Colors.red : Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(_formatRelativeDate(relevantDate), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOverdue ? Colors.red : Colors.grey[600])),
                        ],
                      )
                    else 
                      const SizedBox(),
                      
                    // MINI-BALÃO DE CHAT (Direita)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isInteractive && lastInteraction != null)
                            Expanded(
                              child: InkWell(
                                onTap: () => _showInteractionHistory(order),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: lastInteraction.isProblem ? Colors.red[50] : Colors.grey[100],
                                    // Formato de balão de fala
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(2)),
                                    border: Border.all(color: lastInteraction.isProblem ? Colors.red[200]! : Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(lastInteraction.isProblem ? Icons.warning_amber_rounded : Icons.chat_bubble_outline, size: 10, color: lastInteraction.isProblem ? Colors.red[700] : Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          lastInteraction.text,
                                          style: TextStyle(fontSize: 9, color: lastInteraction.isProblem ? Colors.red[800] : Colors.grey[800], fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                          // BOTÃO ADICIONAR INTERAÇÃO
                          if (order.status == 'sent' && isInteractive) 
                            Padding(
                              padding: const EdgeInsets.only(left: 6), 
                              child: InkWell(
                                onTap: () => _showAddInteractionDialog(order.id), 
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                                  child: const Icon(Icons.add, size: 14, color: Colors.blue)
                                )
                              ),
                            )
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      );
    }

    return Draggable<LabOrderModel>(
      data: order,
      feedback: SizedBox(width: columnWidth, child: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: buildCardContent(isInteractive: false)))),
      childWhenDragging: SizedBox(width: columnWidth, child: IgnorePointer(child: Opacity(opacity: 0.3, child: buildCardContent(isInteractive: false)))),
      child: buildCardContent(isInteractive: true),
    );
  }
}