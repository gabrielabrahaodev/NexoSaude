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

/// Monta o [PatientContext] a partir dos 3 payloads já lidos.
/// Função pura (data/hora via [now]) — mesma semântica do `_loadContext`
/// antigo, agora com as leituras em paralelo via `Future.wait`.
/// `latestClinical`: `{'procedureName', 'date'}` (DateTime ou Timestamp).
/// `unpaid`: lista de `{'dueDate', 'amount'}` (formatos tolerados).
PatientContext combinePatientContext({
  required DateTime now,
  Map<String, dynamic>? latestClinical,
  Map<String, dynamic>? anamnesis,
  List<Map<String, dynamic>> unpaid = const [],
}) {
  DateTime? asDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  final highlights = <String>[];
  if (latestClinical != null) {
    final proc = latestClinical['procedureName'] ?? 'Atendimento';
    final date = asDate(latestClinical['date']);
    final daysAgo = date == null ? 0 : now.difference(date).inDays;
    highlights.add(
        "Último atendimento foi ${daysAgoLabel(daysAgo)} ($proc).");
  } else {
    highlights
        .add("Paciente ainda não possui histórico clínico registrado.");
  }

  final alerts = clinicalAlerts(anamnesis);

  var overdueCount = 0;
  var overdueAmount = 0.0;
  for (final doc in unpaid) {
    final due = asDate(doc['dueDate']);
    // Venceu antes de hoje (mesma regra anterior).
    if (due != null &&
        due.isBefore(now.subtract(const Duration(days: 1)))) {
      overdueCount++;
      final amount = doc['amount'];
      overdueAmount += amount is num ? amount.toDouble() : 0.0;
    }
  }
  if (overdueCount > 0) {
    highlights.add(
        "Possui $overdueCount pendência(s) vencida(s) totalizando ${formatBRL(overdueAmount)}.");
  }

  if (highlights.isEmpty && alerts.isEmpty) {
    return const PatientContext();
  }
  return PatientContext(
    summary: highlights.join("\n"),
    alerts: alerts,
  );
}

class PatientSmartContextCard extends StatefulWidget {
  final String patientId;

  const PatientSmartContextCard({super.key, required this.patientId});

  @override
  State<PatientSmartContextCard> createState() =>
      _PatientSmartContextCardState();
}

class _PatientSmartContextCardState extends State<PatientSmartContextCard> {
  // Carregado UMA vez por inserção: trocar de aba e voltar não refaz as
  // 3 leituras nem remonta o card em pedacinhos (o `future:` inline
  // anterior recriava a cada rebuild).
  late final Future<PatientContext> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadContext();
  }

  /// Essa função atua como o "Cérebro" (AI Engine)
  /// Ela busca dados dispersos e cria um resumo narrativo + alertas.
  /// As 3 leituras rodam em paralelo (`Future.wait`); a montagem é a
  /// função pura [combinePatientContext] (testada).
  Future<PatientContext> _loadContext() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      final results = await Future.wait([
        // 1. ÚLTIMA EVOLUÇÃO CLÍNICA (O que foi feito por último?)
        SessionManager()
            .applyFilter(firestore
                .collection('clinical_records')
                .where('patientId', isEqualTo: widget.patientId))
            .orderBy('date', descending: true)
            .limit(1)
            .get(),
        // 2. ANAMNESE (Saúde Crítica) — mesma fonte do strip.
        firestore.collection('anamnesis').doc(widget.patientId).get(),
        // 3. SITUAÇÃO FINANCEIRA (Inadimplência, apenas não pagos).
        SessionManager()
            .applyFilter(firestore
                .collection('financial')
                .where('patientId', isEqualTo: widget.patientId)
                .where('isPaid', isEqualTo: false))
            .get(),
      ]);

      final clinicalSnap = results[0] as QuerySnapshot;
      final anamnesisSnap =
          results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final financialSnap = results[2] as QuerySnapshot;

      Map<String, dynamic>? latestClinical;
      if (clinicalSnap.docs.isNotEmpty) {
        final data =
            clinicalSnap.docs.first.data() as Map<String, dynamic>;
        latestClinical = {
          'procedureName': data['procedureName'] ?? 'Atendimento',
          'date': data['date'],
        };
      }

      return combinePatientContext(
        now: now,
        latestClinical: latestClinical,
        anamnesis:
            anamnesisSnap.exists ? anamnesisSnap.data() : null,
        unpaid: [
          for (final doc in financialSnap.docs)
            (doc.data() as Map<String, dynamic>),
        ],
      );
    } catch (e) {
      return const PatientContext(); // Falha silenciosa
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PatientContext>(
      future: _future,
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