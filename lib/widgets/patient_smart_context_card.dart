import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../ui/app_theme.dart';
import '../services/session_manager.dart';

class PatientSmartContextCard extends StatelessWidget {
  final String patientId;

  const PatientSmartContextCard({super.key, required this.patientId});

  /// Essa função atua como o "Cérebro" (AI Engine)
  /// Ela busca dados dispersos e cria um resumo narrativo.
  Future<String?> _generateContextSummary() async {
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
        
        String timeStr = daysAgo == 0 ? "hoje" : (daysAgo == 1 ? "ontem" : "há $daysAgo dias");
        highlights.add("Último atendimento foi $timeStr ($proc).");
      } else {
        highlights.add("Paciente ainda não possui histórico clínico registrado.");
      }

      // 2. BUSCAR ALERTAS DE ANAMNESE (Saúde Crítica)
      final anamnesisSnap = await firestore.collection('anamnesis').doc(patientId).get();
      if (anamnesisSnap.exists) {
        final data = anamnesisSnap.data()!;
        List<String> healthAlerts = [];
        
        // Verifica alertas críticos
        if (data['hasAllergies'] == true) healthAlerts.add("Alérgico(a): ${data['allergiesDesc']}");
        if (data['conditions']?['Diabetes'] == true) healthAlerts.add("Diabético");
        if (data['conditions']?['Hipertensão (Pressão Alta)'] == true) healthAlerts.add("Hipertenso");
        if (data['conditions']?['Problemas Cardíacos'] == true) healthAlerts.add("Cardíaco");
        if (data['pregnant'] == true) healthAlerts.add("Gestante");

        if (healthAlerts.isNotEmpty) {
          highlights.add("⚠️ ALERTA CLÍNICO: ${healthAlerts.join(', ')}.");
        }
      }

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
          highlights.add("Possui $overdueCount pendência(s) vencida(s) totalizando R\$ ${overdueAmount.toStringAsFixed(2)}.");
        }
      }

      // Se não tiver nada relevante, retorna null para não exibir o card
      if (highlights.isEmpty) return null;

      // Junta tudo em um texto corrido
      return highlights.join("\n");

    } catch (e) {
      return null; // Falha silenciosa
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _generateContextSummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Gradiente suave para dar ar de "Inteligência Artificial" / Modernidade
            gradient: LinearGradient(
              colors: [Colors.indigo.shade50, Colors.purple.shade50],
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone de "Brilho/IA"
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                      snapshot.data!,
                      style: const TextStyle(
                        fontSize: 13, 
                        color: Colors.black87, 
                        height: 1.4,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}