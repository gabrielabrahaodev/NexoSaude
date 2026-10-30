import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../models/financial_model.dart';
import '../../models/user_model.dart';
import '../../services/agenda_professionals.dart';
import '../../services/appointment_service.dart';
import '../../services/care_day.dart';
import '../../services/portal_mirror.dart';
import '../../services/care_workflow.dart';
import '../../services/clinic_capabilities.dart';
import '../../services/session_manager.dart';
import '../../services/user_service.dart';
import '../../utils/display.dart';
import '../agenda/agenda_cell_factory.dart';
import '../agenda/clinical_agenda_view.dart';
import 'care_visit_screen.dart';
import 'clinical_care_view.dart';

class CareDayScreen extends StatefulWidget {
  const CareDayScreen({super.key});
  @override
  State<CareDayScreen> createState() => _CareDayScreenState();
}

class _CareDayScreenState extends State<CareDayScreen> {
  List<UserModel> _professionals = [];
  StreamSubscription<List<UserModel>>? _members;
  Timer? _dateTimer;
  final Set<String> _selected = {};
  bool _confirming = false;
  String? _directoryError, _professionalFilter, _activeId;
  String _statusFilter = 'Todos';
  late DateTime _date;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _appointments;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _financial;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _contracts;
  bool get _psychology => ClinicCapabilities.current().isPsychology;
  bool get _ownOnly => isCareProfessional(SessionManager().userRole);

  @override
  void initState() {
    super.initState();
    final clinicId = SessionManager().currentClinicId ?? 'waiting_session_init';
    _configureDay();
    _contracts = FirebaseFirestore.instance
        .collection('psychology_schedules')
        .where('clinicId', isEqualTo: clinicId)
        .snapshots();
    _members = UserService()
        .watchAgendaProfessionals(clinicId)
        .listen(
          (users) {
            if (mounted) {
              setState(() {
                _professionals = users;
                if (!users.any((u) => u.id == _professionalFilter)) {
                  _professionalFilter = null;
                }
                _directoryError = null;
              });
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(
                () => _directoryError =
                    'Não foi possível carregar o diretório de profissionais.',
              );
            }
          },
        );
    _dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (todayBounds().start != _date && mounted) {
        setState(() {
          _configureDay();
          _selected.clear();
          _activeId = null;
        });
      }
    });
  }

  void _configureDay() {
    final bounds = todayBounds();
    _date = bounds.start;
    final clinicId = SessionManager().currentClinicId ?? 'waiting_session_init';
    _appointments = FirebaseFirestore.instance
        .collection('appointments')
        .where('clinicId', isEqualTo: clinicId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(bounds.start))
        .where('date', isLessThan: Timestamp.fromDate(bounds.end))
        .snapshots();
    _financial = FirebaseFirestore.instance
        .collection('financial')
        .where('clinicId', isEqualTo: clinicId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(bounds.start))
        .where('date', isLessThan: Timestamp.fromDate(bounds.end))
        .snapshots();
  }

  @override
  void dispose() {
    _members?.cancel();
    _dateTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmSelected(List<AppointmentModel> appointments) async {
    if (_confirming) return;
    setState(() => _confirming = true);
    final failed = <String>[];
    var done = 0;
    for (final a in appointments.where((a) => _selected.contains(a.id))) {
      try {
        final updated = await FirebaseFirestore.instance.runTransaction<bool>((
          tx,
        ) async {
          final ref = FirebaseFirestore.instance
              .collection('appointments')
              .doc(a.id);
          final snap = await tx.get(ref);
          validateCareScope(a, snap.data(), SessionManager().currentClinicId);
          if (!needsConfirmation(
            AppointmentModel.fromMap(a.id, snap.data()!),
          )) {
            return false;
          }
          tx.update(ref, {'status': 'Confirmado'});
          return true;
        });
        if (updated) done++;
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
          ? 'Presença confirmada ($done).'
          : 'Confirmados $done; faltaram: ${failed.join(', ')}.',
      error: failed.isNotEmpty,
    );
  }

  Future<void> _filters() async {
    String? professional = _professionalFilter;
    var status = _statusFilter;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Theme(
        data: ClinicalAgendaStyle.theme,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, modalSetState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros do meu dia',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  if (!_ownOnly)
                    DropdownButtonFormField<String>(
                      initialValue: professional,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Profissional',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Todos os profissionais'),
                        ),
                        ..._professionals.map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.name),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          modalSetState(() => professional = value),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items:
                        [
                              'Todos',
                              'Aguardando Confirmação',
                              'Confirmado',
                              'Em Atendimento',
                              'Pausado',
                              'Finalizado',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (value) =>
                        modalSetState(() => status = value ?? 'Todos'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _professionalFilter = (professional ?? '').isEmpty
                            ? null
                            : professional;
                        _statusFilter = status;
                        _selected.clear();
                        _activeId = null;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newVisit() async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;
    final available = selectableAgendaProfessionals(
      _professionals,
      role: SessionManager().userRole,
      userId: SessionManager().userId,
    );
    if (available.isEmpty) {
      toast(
        context,
        'Aguarde os profissionais da clínica ou confira os vínculos.',
      );
      return;
    }
    var selected = selectedAgendaProfessional(_professionalFilter, available)!;
    Future<List<String>> freeSlots() async {
      final busy = await AppointmentService().getBusySlots(
        clinicId,
        _date,
        dentistId: selected,
      );
      final grade = await clinicGrade(clinicId);
      return grade.where((time) {
        final parts = time.split(':');
        final date = DateTime(
          _date.year,
          _date.month,
          _date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        return date.isAfter(DateTime.now()) &&
            careIntervalIsFree(date, _psychology ? 60 : 30, busy) &&
            careIntervalFitsGrade(date, _psychology ? 60 : 30, grade);
      }).toList();
    }

    var future = freeSlots();
    if (!mounted) return;
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Theme(
        data: ClinicalAgendaStyle.theme,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, modalSetState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _psychology ? 'Nova sessão' : 'Novo encaixe',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    items: available
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        modalSetState(() {
                          selected = value;
                          future = freeSlots();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: future,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const Text(
                          'Não foi possível consultar a disponibilidade. Tente novamente.',
                        );
                      }
                      if (snap.connectionState != ConnectionState.done ||
                          !snap.hasData) {
                        return const LinearProgressIndicator();
                      }
                      if (snap.data!.isEmpty) {
                        return const Text(
                          'Sem intervalo livre restante hoje para este profissional. Use a Agenda para outra data.',
                        );
                      }
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(ctx).height * .5,
                        ),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: snap.data!
                                .map(
                                  (time) => ActionChip(
                                    label: Text(time),
                                    onPressed: () =>
                                        Navigator.pop(ctx, (selected, time)),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    AgendaCellFactory.openForm(
      context: context,
      date: _date,
      time: result.$2,
      selectedDentistId: result.$1,
      fullWeekdayName: (day) => [
        'Segunda',
        'Terça',
        'Quarta',
        'Quinta',
        'Sexta',
        'Sábado',
        'Domingo',
      ][day - 1],
    );
  }

  void _openVisit(AppointmentModel a, bool wide) {
    if (wide) {
      setState(() => _activeId = a.id);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: ClinicalAgendaStyle.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(ctx).height -
                  MediaQuery.viewInsetsOf(ctx).bottom) *
              .94,
          child: CareVisitPanel(
            appointment: a,
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ClinicalAgendaStyle.theme,
    child: Scaffold(
      backgroundColor: ClinicalAgendaStyle.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _appointments,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Não foi possível carregar os atendimentos da clínica.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var appointments =
              snapshot.data!.docs
                  .map((d) => AppointmentModel.fromMap(d.id, d.data()))
                  .where(
                    (a) =>
                        !a.isCancelled &&
                        a.status.toLowerCase() != 'bloqueado' &&
                        (!_ownOnly || a.dentistId == SessionManager().userId),
                  )
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));
          if (_professionalFilter != null && !_ownOnly) {
            appointments = appointments
                .where((a) => a.dentistId == _professionalFilter)
                .toList();
          }
          if (_statusFilter != 'Todos') {
            appointments = appointments
                .where((a) => a.status == _statusFilter)
                .toList();
          }
          final eligible = appointments
              .where(needsConfirmation)
              .map((a) => a.id)
              .toSet();
          if (_selected.any((id) => !eligible.contains(id))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(
                  () => _selected.removeWhere((id) => !eligible.contains(id)),
                );
              }
            });
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _psychology ? _contracts : null,
            builder: (context, contracts) {
              final kinds = {
                for (final d
                    in contracts.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  d.id: '${d.data()['scheduleType'] ?? ''}',
              };
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _financial,
                builder: (context, financial) {
                  final paid = <String>{};
                  for (final d
                      in financial.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                    final m = d.data();
                    if (m['type'] == 'income' &&
                        FinancialModel.isPaidOf(
                          status: '${m['status'] ?? ''}',
                          paidAmount: parseBRL(m['paidAmount']),
                          amount: parseBRL(m['amount']),
                        )) {
                      paid.add('${m['patientId'] ?? ''}');
                    }
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final active = appointments
                          .where((a) => a.id == _activeId)
                          .firstOrNull;
                      return ClinicalCareDayView(
                        date: _date,
                        clinicName:
                            SessionManager().currentClinicName ?? 'Unidade',
                        psychology: _psychology,
                        appointments: appointments,
                        professionals: {
                          for (final u in _professionals) u.id: u.name,
                        },
                        contractKinds: kinds,
                        paidToday: paid,
                        selected: _selected,
                        confirming: _confirming,
                        activeId: _activeId,
                        directoryError:
                            _directoryError ??
                            (financial.hasError
                                ? 'Indicadores financeiros indisponíveis.'
                                : (contracts.hasError
                                      ? 'Tipos de contrato indisponíveis.'
                                      : null)),
                        onSelect: (id, value) => setState(() {
                          if (value) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        }),
                        onOpen: (a) =>
                            _openVisit(a, constraints.maxWidth >= 900),
                        onConfirm: () => _confirmSelected(appointments),
                        onFilters: _filters,
                        onNew: _newVisit,
                        panel: active == null
                            ? null
                            : CareVisitPanel(
                                key: ValueKey(active.id),
                                appointment: active,
                                onClose: () => setState(() => _activeId = null),
                              ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    ),
  );
}
