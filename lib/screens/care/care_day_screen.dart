import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_model.dart';
import '../../models/financial_model.dart';
import '../../services/care_day.dart';
import '../../services/session_manager.dart';
import '../../ui/app_theme.dart';
import '../../utils/display.dart';
import 'care_visit_screen.dart';
import 'remarcar_dialog.dart';

/// Modo Atendimento — "Meu dia" (spec 3.1).
///
/// Lista só hoje da clínica; dentista/psicólogo vê só o próprio,
/// demais roles veem tudo. Selo de pagamento via 1 query extra do dia.
/// Toque abre a ficha de atendimento ([CareVisitScreen]).
class CareDayScreen extends StatefulWidget {
  const CareDayScreen({super.key});

  @override
  State<CareDayScreen> createState() => _CareDayScreenState();
}

class _CareDayScreenState extends State<CareDayScreen> {
  final Map<String, String> _dentists = {};

  @override
  void initState() {
    super.initState();
    _loadDentists();
  }

  /// Nome dos profissionais (a recepção vê todos; o dentista vê só o dele).
  Future<void> _loadDentists() async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('allowedClinics', arrayContains: clinicId)
          .get();
      if (!mounted) return;
      setState(() {
        for (final d in snap.docs) {
          final m = d.data();
          _dentists[d.id] = '${m['name'] ?? m['email'] ?? 'Profissional'}';
        }
      });
    } catch (_) {}
  }

  bool get _ownOnly {
    final role = (SessionManager().userRole ?? '').toLowerCase();
    return role.contains('dentist') ||
        role == 'dentista' ||
        role == 'psicologo';
  }

  Color _statusColor(AppointmentModel a) {
    if (a.isCancelled) return Colors.grey;
    if (a.isDone) return Colors.green;
    final s = a.status.toLowerCase();
    if (s == 'confirmado') return AppColors.primary;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) {
      return const Center(child: Text("Erro: Sessão inválida"));
    }
    final bounds = todayBounds();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
            "Meu dia — Hoje, ${formatDateShort(bounds.start)}"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('clinicId', isEqualTo: clinicId)
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(bounds.start))
            .where('date', isLessThan: Timestamp.fromDate(bounds.end))
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Erro ao carregar o dia: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var appts = snap.data!.docs
              .map((d) => AppointmentModel.fromMap(
                  d.id, d.data() as Map<String, dynamic>))
              .toList();
          if (_ownOnly && uid != null) {
            appts = appts.where((a) => a.dentistId == uid).toList();
          }
          // Bloqueados e cancelados fora do Meu dia.
          appts = appts
              .where((a) =>
                  !a.isCancelled &&
                  a.status.toLowerCase() != 'bloqueado')
              .toList();
          appts.sort((a, b) => a.date.compareTo(b.date));

          if (appts.isEmpty) {
            return const Center(
                child: Text("Nenhum atendimento hoje. Bom descanso!"));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('financial')
                .where('clinicId', isEqualTo: clinicId)
                .where('date',
                    isGreaterThanOrEqualTo:
                        Timestamp.fromDate(bounds.start))
                .where('date',
                    isLessThan: Timestamp.fromDate(bounds.end))
                .snapshots(),
            builder: (context, finSnap) {
              final paidToday = <String>{};
              for (final d in finSnap.data?.docs ?? []) {
                final m = d.data() as Map<String, dynamic>;
                if (FinancialModel.isPaidOf(
                  status: '${m['status'] ?? ''}',
                  paidAmount: parseBRL(m['paidAmount']),
                  amount: parseBRL(m['amount']),
                )) {
                  paidToday.add('${m['patientId'] ?? ''}');
                }
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appts.length,
                itemBuilder: (context, i) {
                  final a = appts[i];
                  final paid = paidToday.contains(a.patientId);
                  final dentistLabel = _ownOnly
                      ? ''
                      : " • ${_dentists[a.dentistId] ?? 'Profissional'}";
                  final isRemarcar =
                      a.status.toLowerCase() == 'remarcar' &&
                          a.proposedDate != null;
                  return Card(
                    color: isRemarcar
                        ? Colors.orange.withValues(alpha: 0.08)
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          DateFormat('HH:mm').format(a.date),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      title: Text(a.patientName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          "${a.procedure}$dentistLabel • ${a.status}${paid ? ' • Pago' : ''}${isRemarcar ? ' • ${formatDateTimeShort(a.proposedDate!)}' : ''}"),
                      trailing: Icon(Icons.chevron_right,
                          color: isRemarcar
                              ? Colors.orange
                              : _statusColor(a)),
                      onTap: () {
                        if (isRemarcar) {
                          showRemarcarDialog(context, a);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    CareVisitScreen(appointment: a)),
                          );
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
