import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../ui/app_theme.dart';
import '../screens/agenda/agenda_form_screen.dart';

/// Função global para exibir o diálogo de cancelamento
void _showCancelDialogGlobal(BuildContext context, DocumentSnapshot doc) {
  final reasonCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text("Cancelar agenda"),
      content: TextField(
        controller: reasonCtrl,
        decoration: const InputDecoration(labelText: "Motivo do cancelamento"),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Voltar")),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            doc.reference.update({
              'status': 'Cancelado',
              'cancelReason': reasonCtrl.text
            });
            Navigator.pop(c);
          },
          child: const Text("Confirmar"),
        ),
      ],
    ),
  );
}

class AppointmentActionCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final bool isDark;
  
  const AppointmentActionCard({
    super.key, 
    required this.doc, 
    required this.isDark
  });

  @override
  Widget build(BuildContext context) {
    // Tratamento de status
    final String status = doc['status'] ?? 'Aguardando Confirmação';
    final DateTime date = (doc['date'] as Timestamp).toDate();
    
    // Regras de bloqueio
    final bool isEncerrado = status == 'Finalizado' || 
                             status == 'Concluído' || 
                             status == 'Cancelado';

    Color color;
    switch (status) {
      case 'Aguardando Confirmação':
        color = Colors.blueGrey;
        break;
      case 'Confirmado': // Padronizado
        color = Colors.orange; // ou Colors.blue
        break;
      case 'Finalizado':
      case 'Concluído':
        color = Colors.green;
        break;
      case 'Cancelado':
        color = AppColors.danger;
        break;
      default:
        color = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome do Paciente e Horário
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  doc['patientName'] ?? 'Paciente',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd/MM • HH:mm').format(date),
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // Descrição do Procedimento
          Text(
            doc['procedure'] ?? '',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),

          // Linha de Status e Ações
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge de Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.chip.copyWith(color: color),
                ),
              ),

              // Grupo de Botões Dinâmicos
              Row(
                children: [
                  // Ação: Confirmar (Aguardando -> Confirmado)
                  if (status == 'Aguardando Confirmação')
                    IconButton(
                      tooltip: "Confirmar Agendamento",
                      icon: const Icon(Icons.thumb_up_alt_outlined, size: 18, color: AppColors.primary),
                      // CORREÇÃO DE FLUXO: Atualiza para 'Confirmado'
                      onPressed: () => doc.reference.update({'status': 'Confirmado'}),
                    ),
                  
                  // Ação: Finalizar (Confirmado -> Finalizado)
                  if (status == 'Confirmado')
                    IconButton(
                      tooltip: "Finalizar Atendimento",
                      icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                      onPressed: () => doc.reference.update({'status': 'Finalizado'}),
                    ),

                  // Botões de Edição: Só aparecem se o evento NÃO estiver encerrado
                  if (!isEncerrado) ...[
                    IconButton(
                      tooltip: "Alterar",
                      icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => AgendaFormScreen(
                            editAppointmentId: doc.id,
                            initialData: doc.data() as Map<String, dynamic>,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: "Cancelar",
                      icon: const Icon(Icons.cancel, size: 18, color: AppColors.danger),
                      onPressed: () => _showCancelDialogGlobal(context, doc),
                    ),
                  ],

                  // Ícone de Cadeado para eventos travados
                  if (isEncerrado && status != 'Cancelado')
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SimpleAppointmentCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const SimpleAppointmentCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final String status = doc['status'] ?? 'Confirmado';
    final DateTime date = (doc['date'] as Timestamp).toDate();
    
    final Color color = (status == 'Finalizado' || status == 'Concluído') 
        ? Colors.green 
        : (status == 'Aguardando Confirmação' ? Colors.blueGrey : AppColors.primary);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['patientName'] ?? 'Paciente', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  "${DateFormat('dd/MM HH:mm').format(date)} • ${doc['procedure'] ?? ''}",
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status, 
              style: AppTextStyles.chip.copyWith(color: color)
            ),
          ),
        ],
      ),
    );
  }
}