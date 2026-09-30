import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_theme.dart';
import '../utils/display.dart';
import '../services/session_manager.dart';

/// Alertas clínicos puros a partir do doc `anamnesis/{patientId}`.
/// Mesma fonte do resumo — o strip fixo e o texto nunca divergem.
List<String> clinicalAlerts(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return const [];
  final alerts = <String>[];
  if (data['hasAllergies'] == true) {
    alerts.add("Alérgico(a): ${data['allergiesDesc']}");
  }
  final conditions = data['conditions'];
  if (conditions is Map) {
    if (conditions['Diabetes'] == true) alerts.add("Diabético");
    if (conditions['Hipertensão (Pressão Alta)'] == true) {
      alerts.add("Hipertenso");
    }
    if (conditions['Problemas Cardíacos'] == true) alerts.add("Cardíaco");
  }
  if (data['pregnant'] == true) alerts.add("Gestante");
  return alerts;
}

/// Contexto do paciente: resumo narrativo + alertas (mesma leitura).
class PatientContext {
  final String? summary;
  final List<String> alerts;

  const PatientContext({this.summary, this.alerts = const []});

  bool get isEmpty => summary == null && alerts.isEmpty;
}

class PatientSmartContextCard extends StatelessWidget {
  final String patientId;

  const PatientSmartContextCard({super.key, required this.patientId});

  /// Essa função atua como o "Cérebro" (AI Engine)
  /// Ela busca dados dispersos e cria um resumo narrativo + alertas.
  /// Uma única leitura da anamnese alimenta strip e texto (sem duplicar).
  Future<PatientContext> _loadContext() async {
    try {
      final firestore = FirebaseFirestore.instance;
      List<String> highlights = [];

      // 1. BUSCAR ÚLTIMA EVOLUÇÃO CLÍNICA (O que foi feito por último?)
      final clinicalSnap = await SessionManager()
          .applyFilter(firestore
              .collection('clinical_records')
              .where('patientId', isEqualTo: patientId))
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (clinicalSnap.docs.isNotEmpty) {
        final data = clinicalSnap.docs.first.data();
        String proc = data['procedureName'] ?? 'Atendimento';
        DateTime date = (data['date'] as Timestamp).toDate();
        int daysAgo = DateTime.now().difference(date).inDays;

        String timeStr = daysAgoLabel(daysAgo);
        highlights.add("Último atendimento foi $timeStr ($proc).");
      } else {
        highlights.add("Paciente ainda não possui histórico clínico registrado.");
      }

      // 2. ALERTAS DE ANAMNESE (Saúde Crítica) — mesma fonte do strip.
      final anamnesisSnap =
          await firestore.collection('anamnesis').doc(patientId).get();
      final alerts = clinicalAlerts(
          anamnesisSnap.exists ? anamnesisSnap.data() : null);

      // 3. BUSCAR SITUAÇÃO FINANCEIRA (Inadimplência)
      final financialSnap = await SessionManager()
          .applyFilter(firestore
              .collection('financial')
              .where('patientId', isEqualTo: patientId)
              .where('isPaid', isEqualTo: false)) // Apenas não pagos
          .get();

      if (financialSnap.docs.isNotEmpty) {
        double overdueAmount = 0;
        int overdueCount = 0;
        final now = DateTime.now();

        for (var doc in financialSnap.docs) {
          final data = doc.data();
          if (data['dueDate'] != null) {
            DateTime due = (data['dueDate'] as Timestamp).toDate();
            // Se venceu antes de hoje
            if (due.isBefore(now.subtract(const Duration(days: 1)))) {
              overdueAmount += (data['amount'] ?? 0);
              overdueCount++;
            }
          }
        }

        if (overdueCount > 0) {
          highlights.add("Possui $overdueCount pendência(s) vencida(s) totalizando ${formatBRL(overdueAmount)}.");
        }
      }

      // Se não tiver nada relevante, retorna contexto vazio (sem card).
      if (highlights.isEmpty && alerts.isEmpty) {
        return const PatientContext();
      }

      // Junta tudo em um texto corrido
      return PatientContext(
        summary: highlights.join("\n"),
        alerts: alerts,
      );

    } catch (e) {
      return const PatientContext(); // Falha silenciosa
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PatientContext>(
      future: _loadContext(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }
        final ctx = snapshot.data!;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Gradiente suave para dar ar de "Inteligência Artificial" / Modernidade
            gradient: LinearGradient(
              colors: AppColors.isDark
                  ? [const Color(0xFF1A2340), const Color(0xFF2A1A40)]
                  : [Colors.indigo.shade50, Colors.purple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Faixa fixa de alertas clínicos (mesma fonte do resumo).
              if (ctx.alerts.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.35)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 18),
                      for (final alert in ctx.alerts)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            alert,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (ctx.summary != null) const SizedBox(height: 12),
              ],
              // Resumo de contexto (wizard).
              if (ctx.summary != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícone de "Brilho/IA"
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.indigo, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // Texto do Resumo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "RESUMO DE CONTEXTO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Colors.indigo
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ctx.summary!,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w500
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}