import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import '../../widgets/page_header.dart';
import '../../models/financial_model.dart';
import 'package:intl/intl.dart';

import '../../services/session_manager.dart';
import '../../utils/display.dart';

/// Dashboard de KPIs da clínica (item 0 do menu).
///
/// Cabeçalho + 4 cards + próximos vencimentos + aniversariantes,
/// com largura máxima para não esticar em telas ultrawide.
class KpiDashboardScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigate;

  const KpiDashboardScreen({super.key, this.onNavigate});

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingFinancial(
      String clinicId) {
    return FirebaseFirestore.instance
        .collection('financial')
        .where('clinicId', isEqualTo: clinicId)
        .where('status', whereIn: ['pendente', 'pending'])
        .where('type', isEqualTo: 'income')
        .snapshots();
  }

  bool _isPaid(Map<String, dynamic> data) {
    return FinancialModel.isPaidOf(
          status: '${data['status']}',
          paidAmount: data['paidAmount'],
          amount: data['amount'],
        ) ||
        data['isPaid'] == true;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value'.replaceAll(',', '.')) ?? 0.0;
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  int? _birthMonth(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    final parts = birthDate.split('/');
    if (parts.length < 2) return null;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return null;
    return month;
  }

  int? _birthDay(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    final parts = birthDate.split('/');
    final day = int.tryParse(parts[0]);
    if (day == null || day < 1 || day > 31) return null;
    return day;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();
    final clinicId = session.currentClinicId;
    if (clinicId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final monthLabel =
        DateFormat('MMMM yyyy', 'pt_BR').format(now);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingFinancial(clinicId),
      builder: (context, finSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('clinicId', isEqualTo: clinicId)
              .where('date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('date', isLessThan: Timestamp.fromDate(endOfDay))
              .snapshots(),
          builder: (context, apptSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .where('clinicId', isEqualTo: clinicId)
                  .where('birthMonth',
                      isEqualTo:
                          DateTime.now().month.toString().padLeft(2, '0'))
                  .snapshots(),
              builder: (context, patSnap) {
                if (finSnap.connectionState == ConnectionState.waiting ||
                    apptSnap.connectionState == ConnectionState.waiting ||
                    patSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                // --- A Receber (mês) + inadimplência ---
                double toReceive = 0;
                double overdue = 0;
                int overdueCount = 0;
                final upcoming = <Map<String, dynamic>>[];
                for (final doc in finSnap.data?.docs ?? []) {
                  final data = doc.data();
                  if (_isPaid(data)) continue;
                  final due = _toDate(data['dueDate']);
                  final amount =
                      _toDouble(data['amount']) - _toDouble(data['paidAmount']);
                  if (due != null &&
                      !due.isBefore(startOfMonth) &&
                      due.isBefore(startOfNextMonth)) {
                    toReceive += amount;
                  }
                  if (due != null && due.isBefore(startOfDay)) {
                    overdue += amount;
                    overdueCount++;
                  }
                  upcoming.add({
                    'name': '${data['patientName'] ?? 'Paciente'}',
                    'title': '${data['title'] ?? ''}',
                    'due': due,
                    'amount': amount,
                  });
                }
                upcoming.sort((a, b) {
                  final da = a['due'] as DateTime?;
                  final db = b['due'] as DateTime?;
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return da.compareTo(db);
                });

                // --- Agendamentos hoje (só confirmados) ---
                final todayCount = (apptSnap.data?.docs ?? [])
                    .where((d) => d.data()['status'] == 'Confirmado')
                    .length;

                // --- Aniversariantes do mês ---
                final birthdays = <Map<String, dynamic>>[];
                for (final doc in patSnap.data?.docs ?? []) {
                  final data = doc.data();
                  if (_birthMonth(data['birthDate']?.toString()) ==
                      now.month) {
                    birthdays.add({
                      'name': '${data['name'] ?? 'Sem nome'}',
                      'day': _birthDay(data['birthDate']?.toString()) ?? 0,
                    });
                  }
                }
                birthdays.sort((a, b) =>
                    (a['day'] as int).compareTo(b['day'] as int));

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            clinicName:
                                session.currentClinicName ?? 'Clínica',
                            monthLabel: monthLabel,
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow =
                                  constraints.maxWidth < 720;
                              final cards = [
                                _KpiCard(
                                  label: "A receber",
                                  value:
                                      "${formatBRL(toReceive)}",
                                  caption: "neste mês",
                                  color: const Color(0xFF1E88E5),
                                  icon: Icons.trending_up,
                                ),
                                _KpiCard(
                                  label: "Inadimplência",
                                  value:
                                      "${formatBRL(overdue)}",
                                  caption: "$overdueCount em atraso",
                                  color: const Color(0xFFE53935),
                                  icon: Icons.warning_amber_rounded,
                                ),
                                _KpiCard(
                                  label: "Hoje",
                                  value: "$todayCount",
                                  caption: todayCount == 1
                                      ? "agendamento"
                                      : "agendamentos",
                                  color: const Color(0xFF43A047),
                                  icon: Icons.calendar_today,
                                ),
                                _KpiCard(
                                  label: "Aniversariantes",
                                  value: "${birthdays.length}",
                                  caption: DateFormat('MMMM', 'pt_BR')
                                      .format(now),
                                  color: const Color(0xFF8E24AA),
                                  icon: Icons.cake,
                                ),
                              ];
                              if (narrow) {
                                return Column(
                                  children: [
                                    Row(children: [
                                      Expanded(child: cards[0]),
                                      const SizedBox(width: 12),
                                      Expanded(child: cards[1]),
                                    ]),
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      Expanded(child: cards[2]),
                                      const SizedBox(width: 12),
                                      Expanded(child: cards[3]),
                                    ]),
                                  ],
                                );
                              }
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0;
                                        i < cards.length;
                                        i++) ...[
                                      if (i > 0)
                                        const SizedBox(width: 12),
                                      Expanded(child: cards[i]),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _SectionTitle(
                            icon: Icons.schedule,
                            title: "Próximos vencimentos",
                            actionLabel: "Cobranças",
                            onAction: onNavigate == null
                                ? null
                                : () => onNavigate!(7),
                          ),
                          const SizedBox(height: 8),
                          _Panel(
                            child: upcoming.isEmpty
                                ? const _EmptyState(
                                    icon: Icons.check_circle_outline,
                                    text:
                                        "Nenhuma conta pendente. Tudo em dia!",
                                  )
                                : Column(
                                    children: [
                                      for (var i = 0;
                                          i <
                                              upcoming
                                                  .take(5)
                                                  .length;
                                          i++) ...[
                                        if (i > 0)
                                          const Divider(
                                              height: 1, indent: 44),
                                        _DueRow(
                                          item: upcoming[i],
                                          startOfDay: startOfDay,
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _SectionTitle(
                            icon: Icons.cake_outlined,
                            title: "Aniversariantes do mês",
                            actionLabel: "Pacientes",
                            onAction: onNavigate == null
                                ? null
                                : () => onNavigate!(2),
                          ),
                          const SizedBox(height: 8),
                          _Panel(
                            child: birthdays.isEmpty
                                ? const _EmptyState(
                                    icon:
                                        Icons.sentiment_satisfied_alt,
                                    text:
                                        "Nenhum aniversariante este mês.",
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: birthdays
                                        .map((b) => Chip(
                                              avatar: const Icon(
                                                  Icons.cake,
                                                  size: 16),
                                              label: Text(
                                                  "${b['name']} • dia ${b['day']}",
                                                  style:
                                                      const TextStyle(
                                                          fontSize: 13)),
                                            ))
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String clinicName;
  final String monthLabel;

  const _Header({required this.clinicName, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    return PageTitle(
      title: "Visão geral",
      subtitle: "$clinicName • $monthLabel",
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            caption,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text("Ver em $actionLabel"),
          ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _DueRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final DateTime startOfDay;

  const _DueRow({required this.item, required this.startOfDay});

  @override
  Widget build(BuildContext context) {
    final due = item['due'] as DateTime?;
    final isOverdue = due != null && due.isBefore(startOfDay);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOverdue ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  '${item['title']}${due != null ? ' • Vence ${formatDateShort(due)}' : ''}',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (isOverdue)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "ATRASADO",
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red),
              ),
            ),
          Text(
            "${formatBRL((item['amount'] as double))}",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
