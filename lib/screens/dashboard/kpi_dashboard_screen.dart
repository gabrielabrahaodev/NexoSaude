import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'clinical_dashboard_view.dart';

import '../../models/financial_model.dart';
import '../../models/patient_model.dart';
import '../../utils/display.dart' show parseBRL;
import '../agenda/agenda_cell_factory.dart';
import 'package:intl/intl.dart';

import '../../services/session_manager.dart';


/// Dashboard de KPIs da clínica (item 0 do menu).
///
/// Cabeçalho + 4 cards + próximos vencimentos + aniversariantes,
/// com largura máxima para não esticar em telas ultrawide.
class KpiDashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const KpiDashboardScreen({super.key, this.onNavigate});

  @override
  State<KpiDashboardScreen> createState() => _KpiDashboardScreenState();
}

class _KpiDashboardScreenState extends State<KpiDashboardScreen> {
  ValueChanged<int>? get onNavigate => widget.onNavigate;
  String? _streamKey;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _financialStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _appointmentsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _birthdaysStream;

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingFinancial(
      String clinicId) {
    return FirebaseFirestore.instance
        .collection('financial')
        .where('clinicId', isEqualTo: clinicId)
        .where('status', whereIn: ['pendente', 'pending', 'cobrado', 'parcial', 'partial'])
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
    return parseBRL(value);
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return value is String ? DateTime.tryParse(value) : null;
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

    final streamKey = '$clinicId|$startOfDay';
    if (_streamKey != streamKey) {
      _streamKey = streamKey;
      // Explicit clinicId scope is required even for owner/ALL sessions.
      _financialStream = _pendingFinancial(clinicId);
      _appointmentsStream = FirebaseFirestore.instance.collection('appointments')
          .where('clinicId', isEqualTo: clinicId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay)).snapshots();
      _birthdaysStream = FirebaseFirestore.instance.collection('patients')
          .where('clinicId', isEqualTo: clinicId)
          .where('birthMonth', isEqualTo: now.month.toString().padLeft(2, '0')).snapshots();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _financialStream,
      builder: (context, finSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _appointmentsStream,
          builder: (context, apptSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _birthdaysStream,
              builder: (context, patSnap) {
                if (finSnap.hasError || apptSnap.hasError || patSnap.hasError) {
                  return const Center(child: Text('Não foi possível carregar o Dashboard. Tente novamente ao reabrir a tela.'));
                }
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
                  if (_isPaid(data) || _toDouble(data['amount']) <= _toDouble(data['paidAmount'])) continue;
                  final due = _toDate(data['dueDate']);
                  final amount =
                      _toDouble(data['amount']) - _toDouble(data['paidAmount']);
                  if (amount <= 0) continue;
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
                    'title': '${data['title'] ?? data['description'] ?? ''}',
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

                // --- Exceções do dia (3 regras, mesmos streams) ---
                final overdueIds = <String>{};
                var oldOverdueCount = 0;
                final weekAgo = startOfDay.subtract(const Duration(days: 7));
                for (final doc in finSnap.data?.docs ?? []) {
                  final data = doc.data();
                  if (_isPaid(data) || _toDouble(data['amount']) <= _toDouble(data['paidAmount'])) continue;
                  final due = _toDate(data['dueDate']);
                  if (due != null && due.isBefore(startOfDay)) {
                    final patientId = '${data['patientId'] ?? ''}';
                    if (patientId.isNotEmpty) overdueIds.add(patientId);
                    if (!due.isAfter(weekAgo)) oldOverdueCount++;
                  }
                }
                final todayAppts = (apptSnap.data?.docs ?? []).where((d) {
                  final st = '${d.data()['status'] ?? ''}';
                  return st != 'Cancelado' && st != 'Bloqueado';
                }).toList();
                final noConfirm = todayAppts
                    .where((d) =>
                        '${d.data()['status'] ?? ''}' ==
                        'Aguardando Confirmação')
                    .toList();
                final debtorsToday = todayAppts
                    .where((d) =>
                        '${d.data()['status'] ?? ''}' == 'Confirmado' &&
                        overdueIds
                            .contains('${d.data()['patientId'] ?? ''}'))
                    .toList();

                // --- Aniversariantes do mês ---
                final birthdays = <Map<String, dynamic>>[];
                for (final doc in patSnap.data?.docs ?? []) {
                  final data = doc.data();
                  final birthDate = PatientModel.fromMap(doc.id, data).birthDate;
                  if (_birthMonth(birthDate) ==
                      now.month) {
                    birthdays.add({
                      'name': '${data['name'] ?? 'Sem nome'}',
                      'day': _birthDay(birthDate) ?? 0,
                    });
                  }
                }
                birthdays.sort((a, b) =>
                    (a['day'] as int).compareTo(b['day'] as int));

                return ClinicalDashboardView(
                  monthLabel: monthLabel,
                  toReceive: toReceive, overdue: overdue,
                  overdueCount: overdueCount, todayCount: todayCount,
                  oldOverdueCount: oldOverdueCount,
                  unconfirmedCount: noConfirm.length,
                  debtorsTodayCount: debtorsToday.length,
                  upcoming: upcoming.take(5).toList(), birthdays: birthdays,
                  now: now, onNavigate: onNavigate,
                  onNewAppointment: () => AgendaCellFactory.openForm(
                    context: context, date: now, time: '08:00',
                    selectedDentistId: null,
                    fullWeekdayName: (day) => const ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'][day - 1],
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
