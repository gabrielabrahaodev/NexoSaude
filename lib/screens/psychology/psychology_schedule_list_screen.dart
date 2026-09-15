import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/psychology_schedule_service.dart';
import '../../models/psychology_schedule_model.dart';
import 'psychology_schedule_form_screen.dart';

class PsychologyScheduleListScreen extends StatefulWidget {
  const PsychologyScheduleListScreen({super.key});
  @override
  State<PsychologyScheduleListScreen> createState() => _PsychologyScheduleListScreenState();
}

class _PsychologyScheduleListScreenState extends State<PsychologyScheduleListScreen> {
  final _service = PsychologyScheduleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agendas de Psicologia"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PsychologyScheduleFormScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getSchedulesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("Nenhuma agenda de psicologia cadastrada"),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Criar Primeira Agenda"),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PsychologyScheduleFormScreen()),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final schedule = PsychologyScheduleModel.fromMap(docs[index].id, docs[index].data() as Map<String, dynamic>);
              return _buildScheduleCard(schedule, docs[index].id);
            },
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(PsychologyScheduleModel schedule, String docId) {
    final typeLabel = schedule.scheduleType == PsychologyScheduleType.package ? "Pacote" : "Sessão Avulsa";
    final typeColor = schedule.scheduleType == PsychologyScheduleType.package ? Colors.purple : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(DateFormat('dd/MM/yyyy').format(schedule.startDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            Text(schedule.patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text("${schedule.dayOfWeek}s às ${schedule.time}"),
                const SizedBox(width: 16),
                if (schedule.scheduleType == PsychologyScheduleType.package) ...[
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text("Pacote: R\$ ${schedule.packageValue.toStringAsFixed(2)}"),
                ] else ...[
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text("Sessão: R\$ ${schedule.sessionValue.toStringAsFixed(2)}"),
                ],
              ],
            ),
            if (schedule.fromThirdParty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.local_offer, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text("Convênio/Indicação - Desconto: R\$ ${schedule.thirdPartyDiscount.toStringAsFixed(2)}"),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Editar"),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PsychologyScheduleFormScreen(editScheduleId: docId, initialData: schedule.toMap())),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text("Cancelar", style: TextStyle(color: Colors.red)),
                  onPressed: () => _confirmDelete(docId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancelar Agenda"),
        content: const Text("Isso cancelará todas as sessões futuras geradas. Continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Não")),
          TextButton(
            onPressed: () async {
              await _service.delete(docId);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agenda cancelada")));
            },
            child: const Text("Sim, Cancelar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}