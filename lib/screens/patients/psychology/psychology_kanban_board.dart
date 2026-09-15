import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Enum para tipar os status e evitar "Strings Mágicas" (Regra do Dr. Code)
enum PatientStatus { lead, active, discharged }

class PsychologyKanbanBoard extends StatelessWidget {
  const PsychologyKanbanBoard({super.key});

  @override
  Widget build(BuildContext context) {
    // Layout horizontal para o Kanban com rolagem
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão de Pacientes (PsychoFlow)"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Container(
        color: const Color(0xFFF5F7FA), // Fundo suave para não cansar a vista
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna 1: Leads (Vendas/CRM)
              _buildKanbanColumn(
                context,
                "Triagem / Leads",
                PatientStatus.lead,
                Colors.blue,
                icon: Icons.person_add_alt_1,
              ),
              // Coluna 2: Ativos (Clínico/Financeiro)
              _buildKanbanColumn(
                context,
                "Em Acompanhamento",
                PatientStatus.active,
                Colors.green,
                icon: Icons.favorite,
              ),
              // Coluna 3: Alta (Retenção/Histórico)
              _buildKanbanColumn(
                context,
                "Alta / Manutenção",
                PatientStatus.discharged,
                Colors.grey,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context,
    String title,
    PatientStatus status,
    Color color, {
    required IconData icon,
  }) {
    return Container(
      width: 320, // Largura fixa para cada coluna
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho da Coluna com Design "Clean"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Área de Drop (DragTarget)
          Expanded(
            child: DragTarget<DocumentSnapshot>(
              onWillAccept: (data) => true, // Aceita qualquer card de paciente
              onAccept: (patientDoc) {
                // AQUI ACONTECE A MÁGICA DA TRANSIÇÃO SEGURA
                _handleStatusTransition(context, patientDoc, status);
              },
              builder: (context, candidateData, rejectedData) {
                // Stream dedicado para esta coluna (Performance: filtra no server)
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('patients')
                      .where('status', isEqualTo: status.name)
                      // Otimização: ordenar por última sessão para ver quem precisa de atenção
                      // .orderBy('last_session_date', descending: true) // Requer índice no Firebase
                      .snapshots(),
                  builder: (context, snapshot) {
                    // Estado de Carregamento
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(candidateData.isNotEmpty);
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        return _buildDraggableCard(snapshot.data!.docs[index], color);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isHovering) {
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isHovering ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHovering ? Icons.move_to_inbox : Icons.inbox_outlined,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(
              isHovering ? "Solte para mover" : "Nenhum paciente",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableCard(DocumentSnapshot doc, Color statusColor) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Paciente Sem Nome';
    
    // Implementação do "Mood Card" (Borda colorida baseada em humor/status financeiro)
    // Aqui simulado: se tiver 'alert' no doc, fica vermelho. Senão, cor do status.
    final hasAlert = data['has_alert'] == true; 
    final borderColor = hasAlert ? Colors.redAccent : statusColor.withValues(alpha: 0.3);

    // O Widget visual do Card (Privacy First: Sem dados clínicos)
    final cardWidget = Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: hasAlert ? 2 : 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: Nome e Avatar
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Linha 2: Metadados Administrativos (Seguro para Recepcionista ver)
            Row(
              children: [
                _buildTag(Icons.calendar_today, _formatDate(data['last_session_date'])),
                const Spacer(),
                if (data['financial_status'] == 'pending')
                  const Icon(Icons.attach_money, size: 16, color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );

    // Envolvemos no Draggable para permitir arrastar
    return Draggable<DocumentSnapshot>(
      data: doc,
      feedback: SizedBox(
        width: 300,
        child: Opacity(
          opacity: 0.9,
          child: Transform.rotate(
            angle: 0.05, // Leve rotação para feedback visual de "pegou"
            child: cardWidget,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cardWidget), // O "fantasma" que fica
      child: cardWidget,
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // --- LÓGICA DE TRANSIÇÃO SEGURA (GATEKEEPER) ---
  void _handleStatusTransition(BuildContext context, DocumentSnapshot doc, PatientStatus newStatus) {
    final data = doc.data() as Map<String, dynamic>;
    // Converte string do banco para Enum (Fallback para 'lead' se erro)
    final currentStatusStr = data['status'] ?? 'lead';
    PatientStatus currentStatus;
    try {
      currentStatus = PatientStatus.values.firstWhere((e) => e.name == currentStatusStr);
    } catch (e) {
      currentStatus = PatientStatus.lead;
    }

    // Se soltou na mesma coluna, não faz nada
    if (currentStatus == newStatus) return;

    // REGRA 1 (SecOps): Lead -> Ativo exige burocracia
    if (newStatus == PatientStatus.active) {
      _showStartTreatmentDialog(context, doc, newStatus);
    } 
    // REGRA 2 (Growth): Ativo -> Alta exige motivo (retenção)
    else if (newStatus == PatientStatus.discharged) {
      _showDischargeDialog(context, doc, newStatus);
    } 
    // REGRA 3: Movimentação livre para Lead (ex: cancelou antes de começar)
    else {
      doc.reference.update({'status': newStatus.name});
    }
  }

  // Dialog de Início de Tratamento (Consentimento Informado)
  void _showStartTreatmentDialog(BuildContext context, DocumentSnapshot doc, PatientStatus newStatus) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obriga a decisão
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.security, color: Colors.blue),
            SizedBox(width: 10),
            Text("Iniciar Tratamento"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Você está movendo este paciente para a área clínica (LGPD/HIPAA)."),
            SizedBox(height: 10),
            Text("Confirme os requisitos obrigatórios:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            _CheckItem(label: "Contrato Terapêutico Assinado"),
            _CheckItem(label: "Anamnese Inicial Preenchida"),
            _CheckItem(label: "Dados de Faturamento (CPF/Convênio)"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // Cancela, volta pro lugar
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Atualiza no Firebase
              doc.reference.update({
                'status': newStatus.name,
                'treatment_start_date': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Paciente ativado com sucesso!")),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text("Confirmar Início"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  // Dialog de Alta (Motivo)
  void _showDischargeDialog(BuildContext context, DocumentSnapshot doc, PatientStatus newStatus) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Registrar Alta / Pausa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Qual o motivo do encerramento? Essa informação é crucial para métricas de retenção."),
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: "Motivo (ex: Alta clínica, Financeiro...)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              doc.reference.update({
                'status': newStatus.name,
                'discharge_reason': reasonController.text,
                'discharge_date': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
            child: const Text("Arquivar Paciente"),
          )
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Sem data";
    // Formata para dia/mês (ex: 12/Out)
    return DateFormat('dd/MM').format(timestamp.toDate());
  }
}

// Widget auxiliar simples para os checkboxes do Dialog
class _CheckItem extends StatelessWidget {
  final String label;
  const _CheckItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          const Icon(Icons.check_box_outline_blank, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}