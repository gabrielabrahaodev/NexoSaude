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
import '../../utils/patient_route.dart';
import '../../widgets/status_chip.dart';
import 'care_visit_screen.dart';
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

  /// Seleção p/ confirmação de presença em lote.
  final Set<String> _selected = {};
  bool _confirming = false;

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

  /// Confirma presença em lote (1 escrita por doc; falha parcial avisa
  /// quais faltaram).
  Future<void> _confirmSelected(List<AppointmentModel> appts) async {
    final targets =
        appts.where((a) => _selected.contains(a.id)).toList();
    if (targets.isEmpty || _confirming) return;
    setState(() => _confirming = true);
    final failed = <String>[];
    var done = 0;
    for (final a in targets) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(a.id)
            .update({'status': 'Confirmado'});
        done++;
      } catch (_) {
        failed.add(a.patientName);
      }
    }
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _selected.clear();
    });
    toast(
      context,
      failed.isEmpty
          ? "Presença confirmada ($done)."
          : "Confirmados $done; faltaram: ${failed.join(', ')}.",
      error: failed.isNotEmpty,
    );
  }

  Color _statusColor(AppointmentModel a) {
    if (a.isCancelled) return Colors.grey;
    if (a.isDone) return Colors.green;
    final s = a.status.toLowerCase();
    if (s == 'confirmado') return AppColors.primary;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) {
      return const Center(child: Text("Erro: Sessão inválida"));
    }
    final bounds = todayBounds();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
            "Meu dia • Hoje, ${formatDateShort(bounds.start)}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
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
              // Poda seleção obsoleta (ex.: confirmado na ficha).
              final eligibleIds = {
                for (final a in appts)
                  if (needsConfirmation(a)) a.id
              };
              if (_selected.any((id) => !eligibleIds.contains(id))) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selected
                      .removeWhere((id) => !eligibleIds.contains(id)));
                });
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: appts.length,
                      itemBuilder: (context, i) {
                        final a = appts[i];
                        final paid = paidToday.contains(a.patientId);
                        final dentistLabel = _ownOnly
                            ? ''
                            : " • ${_dentists[a.dentistId] ?? 'Profissional'}";
                        final selectable = needsConfirmation(a);
                        return _VisitCard(
                          appt: a,
                          paid: paid,
                          dentistLabel: dentistLabel,
                          accent: _statusColor(a),
                          onOpen: () {
                            _openVisitSheet(context, a);
                          },
                          selectable: selectable,
                          selected: _selected.contains(a.id),
                          onSelect: selectable
                              ? (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(a.id);
                                    } else {
                                      _selected.remove(a.id);
                                    }
                                  })
                              : null,
                        );
                      },
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _confirming
                                ? null
                                : () => _confirmSelected(appts),
                            icon: _confirming
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.check),
                            label: Text(_confirming
                                ? "Confirmando..."
                                : "Confirmar presença (${_selected.length})"),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Ficha em modal (sem nova tela): 92% da altura, com alça e fechar.
void _openVisitSheet(BuildContext context, AppointmentModel a) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.92,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      "${a.patientName} • ${DateFormat('HH:mm').format(a.date)}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: "Fechar",
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: CareVisitPanel(appointment: a)),
        ],
      ),
    ),
  );
}

/// Card translúcido do atendimento: vidro fosco leve (sem BackdropFilter
/// por custo em lista), acento na cor do status + selo.
class _VisitCard extends StatelessWidget {
  final AppointmentModel appt;
  final bool paid;
  final String dentistLabel;
  final Color accent;
  final VoidCallback onOpen;

  /// Seleção p/ presença em lote (só rows elegíveis recebem checkbox).
  final bool selectable;
  final bool selected;
  final ValueChanged<bool?>? onSelect;

  const _VisitCard({
    required this.appt,
    required this.paid,
    required this.dentistLabel,
    required this.accent,
    required this.onOpen,
    this.selectable = false,
    this.selected = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final a = appt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface
            .withValues(alpha: AppColors.isDark ? 0.72 : 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (selectable)
                      Checkbox(
                        value: selected,
                        onChanged: onSelect,
                        visualDensity: VisualDensity.compact,
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        DateFormat('HH:mm').format(a.date),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a.patientName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    StatusChip(label: a.status, color: accent),
                    IconButton(
                      icon: const Icon(Icons.person_outline, size: 20),
                      color: Colors.blue,
                      tooltip: "Abrir paciente",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.push(
                          context,
                          openPatient(
                              a.patientId, a.patientName)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          "${a.procedure}$dentistLabel${paid ? ' • Pago' : ''}",
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(Icons.open_in_full,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
