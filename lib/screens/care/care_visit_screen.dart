import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_model.dart';
import '../../models/financial_model.dart';
import '../../models/psychology_schedule_model.dart';
import '../../models/user_model.dart';
import '../../services/agenda_professionals.dart';
import '../../services/appointment_service.dart';
import '../../services/care_day.dart';
import '../../services/care_visit_service.dart';
import '../../services/care_workflow.dart';
import '../../services/clinic_capabilities.dart';
import '../../services/financial_service.dart';
import '../../services/session_manager.dart';
import '../../services/user_service.dart';
import '../../services/portal_mirror.dart';
import '../../utils/display.dart';
import '../../utils/external_link.dart';
import '../../utils/patient_route.dart';
import '../../widgets/patient_smart_context_card.dart';
import '../agenda/clinical_agenda_view.dart';
import '../psychology/psychology_schedule_form_screen.dart';
import 'clinical_care_view.dart';

class CareVisitScreen extends StatelessWidget {
  final AppointmentModel appointment;
  const CareVisitScreen({super.key, required this.appointment});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClinicalAgendaStyle.background,
    appBar: AppBar(title: Text(appointment.patientName)),
    body: CareVisitPanel(
      appointment: appointment,
      onClose: () => Navigator.pop(context),
    ),
  );
}

class CareVisitPanel extends StatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback? onClose;
  const CareVisitPanel({super.key, required this.appointment, this.onClose});
  @override
  State<CareVisitPanel> createState() => _CareVisitPanelState();
}

class _CareVisitPanelState extends State<CareVisitPanel> {
  final _detailsCtrl = TextEditingController();
  final Set<String> _markers = {};
  final _service = CareVisitService();
  Timer? _draftTimer;
  Completer<void>? _draftDone;
  bool _loadingDraft = true,
      _dirty = false,
      _saving = false,
      _draftSaving = false;
  bool _evolutionSaved = false,
      _loadingCharges = true,
      _loadingSuggestion = false;
  String _draftStatus = 'Carregando registro…';
  String? _phone, _chargesError, _contextError, _directoryError;
  String? _selectedChargeId, _nextDentistId, _professionalName;
  String _method = 'Pix';
  late String _status;
  late final bool _psychology;
  final List<String> _alerts = [];
  List<FinancialModel> _openCharges = [];
  List<UserModel> _nextDentists = [];
  DateTime? _nextDate, _suggestedDate;
  bool? _suggestedFree;
  int _suggestionGeneration = 0;
  PsychologyScheduleModel? _contract;
  CarePackageProgress? _packageProgress;
  bool _loadingPackage = false;
  String? _packageError, _recordError;
  static const _methods = [
    'Dinheiro',
    'Pix',
    'Cartão de crédito',
    'Cartão de débito',
  ];
  AppointmentModel get _a => widget.appointment;
  bool get _done => _status == 'Finalizado';
  bool get _monthlyPackage =>
      _psychology && _contract?.scheduleType == PsychologyScheduleType.package;
  String get _description => careEvolutionText(_markers, _detailsCtrl.text);

  @override
  void initState() {
    super.initState();
    _psychology = ClinicCapabilities.current().isPsychology;
    _status = _a.status;
    _nextDentistId = _a.dentistId;
    _detailsCtrl.addListener(_changed);
    CareDraftRegistry.register(this, _flushBeforeNavigation);
    _loadRecord();
    _loadPatient();
    _loadOpenCharges();
    _loadProfessionals();
    if (_psychology) _loadPackage();
  }

  @override
  void didUpdateWidget(covariant CareVisitPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appointment.status != oldWidget.appointment.status) {
      _status = widget.appointment.status;
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    CareDraftRegistry.unregister(this);
    // Última edição também é enviada ao sair pelo menu; não usa armazenamento local.
    if (_dirty && !_done && !_loadingDraft) {
      unawaited(
        _service
            .saveDraft(_a, text: _detailsCtrl.text, markers: _markers.toList())
            .catchError((Object error) {
              debugPrint('Falha no rascunho de atendimento: $error');
            }),
      );
    }
    _detailsCtrl.removeListener(_changed);
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    if (mounted) {
      setState(() {
        _loadingDraft = true;
        _recordError = null;
      });
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(_a.id)
          .get();
      validateCareScope(_a, snap.data(), SessionManager().currentClinicId);
      final data = snap.data()!;
      final drafts = data['careDrafts'];
      final draft = drafts is Map ? drafts[SessionManager().userId] : null;
      String? published;
      final recordId = data['careEvolutionId'];
      if (recordId is String && recordId.isNotEmpty) {
        final record = await FirebaseFirestore.instance
            .collection('clinical_records')
            .doc(recordId)
            .get();
        final note = record.data();
        if (note?['clinicId'] == _a.clinicId &&
            note?['patientId'] == _a.patientId) {
          published = note?['description']?.toString();
        }
      }
      if (!mounted) return;
      _status = '${data['status'] ?? _a.status}';
      if (draft is Map && !_done) {
        _detailsCtrl.text = '${draft['text'] ?? ''}';
        _markers.addAll(
          (draft['markers'] is List ? draft['markers'] as List : []).map(
            (v) => '$v',
          ),
        );
      } else if (published != null) {
        _detailsCtrl.text = published;
        _evolutionSaved = true;
      }
      setState(() {
        _loadingDraft = false;
        _draftStatus = _done
            ? 'Atendimento finalizado. Registro disponível no prontuário.'
            : (draft is Map
                  ? 'Rascunho recuperado do atendimento.'
                  : 'Nenhuma alteração pendente.');
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingDraft = false;
          _recordError =
              'Não foi possível carregar o registro. Tente novamente.';
        });
      }
    }
  }

  void _changed() {
    if (_loadingDraft || _done || _saving) return;
    _draftTimer?.cancel();
    setState(() {
      _dirty = true;
      _evolutionSaved = false;
      _draftStatus = 'Alterações pendentes…';
    });
    _draftTimer = Timer(const Duration(milliseconds: 1000), _saveDraft);
  }

  Future<bool> _saveDraft() async {
    if (_done || _loadingDraft) return false;
    if (_draftSaving) return false;
    final text = _detailsCtrl.text;
    final markers = _markers.toList();
    _draftSaving = true;
    final done = Completer<void>();
    _draftDone = done;
    var changedDuringSave = false;
    try {
      await _service.saveDraft(_a, text: text, markers: markers);
      if (!mounted) return true;
      final unchanged =
          text == _detailsCtrl.text &&
          careEvolutionText(markers, '') == careEvolutionText(_markers, '');
      changedDuringSave = !unchanged;
      setState(() {
        _dirty = !unchanged;
        _draftStatus = unchanged
            ? 'Rascunho salvo no atendimento.'
            : 'Alterações pendentes…';
      });
      return unchanged;
    } catch (error) {
      if (mounted) {
        setState(
          () => _draftStatus =
              'Não foi possível salvar o rascunho. Tente novamente.',
        );
      }
      return false;
    } finally {
      _draftSaving = false;
      done.complete();
      if (identical(_draftDone, done)) _draftDone = null;
      if (changedDuringSave && mounted && !_done) {
        _draftTimer?.cancel();
        _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
      }
    }
  }

  Future<bool> _flushBeforeNavigation() async {
    if (_saving) return false;
    if (_draftSaving) await _draftDone?.future;
    if (!mounted) return false;
    if (!_dirty || _done || _loadingDraft) return true;
    _draftTimer?.cancel();
    return _saveDraft();
  }

  Future<void> _close() async {
    _draftTimer?.cancel();
    if (!await _flushBeforeNavigation()) {
      if (mounted) {
        toast(
          context,
          'O rascunho ainda não foi salvo. Tente novamente.',
          error: true,
        );
      }
      return;
    }
    if (mounted) widget.onClose?.call();
  }

  Future<void> _saveEvolution({bool finalize = false}) async {
    if (_saving || _done || _loadingDraft) return;
    if (_description.isEmpty) {
      toast(context, 'Descreva a evolução antes de salvar.');
      return;
    }
    _draftTimer?.cancel();
    setState(() => _saving = true);
    try {
      // Espera o rascunho em andamento para não escrevê-lo após a publicação.
      if (_draftSaving) {
        toast(context, 'Aguarde o rascunho terminar de salvar.');
        return;
      }
      await _service.saveEvolution(
        _a,
        description: _description,
        psychology: _psychology,
        finalize: finalize,
      );
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _evolutionSaved = true;
        if (finalize) _status = 'Finalizado';
        _draftStatus = finalize
            ? 'Atendimento finalizado e presença registrada.'
            : 'Evolução salva no prontuário. Atendimento ainda aberto.';
      });
      if (_psychology) await _loadPackage();
      if (mounted) {
        toast(
          context,
          finalize ? 'Atendimento finalizado.' : 'Evolução salva.',
          ok: true,
        );
      }
    } catch (error) {
      if (mounted) toast(context, 'Erro ao salvar: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startPause() async {
    if (_saving || _done) return;
    final status = careInProgress(_status) ? 'Pausado' : 'Em Atendimento';
    setState(() => _saving = true);
    try {
      if (_dirty && !await _saveDraft()) {
        throw StateError('O rascunho ainda não foi salvo.');
      }
      await _service.changeStatus(_a, status);
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadPatient() async {
    try {
      final patient = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_a.patientId)
          .get();
      if (patient.data()?['clinicId'] != _a.clinicId) {
        throw StateError('Paciente fora da clínica.');
      }
      if (mounted) setState(() => _phone = '${patient.data()?['phone'] ?? ''}');
      final anamnesis = !_psychology
          ? await FirebaseFirestore.instance
                .collection('anamnesis')
                .doc(_a.patientId)
                .get()
          : null;
      if (!mounted) return;
      setState(() {
        _phone = '${patient.data()?['phone'] ?? ''}';
        _alerts.addAll(clinicalAlerts(anamnesis?.data()));
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _contextError =
              'Resumo clínico indisponível. Consulte o prontuário antes do atendimento.',
        );
      }
    }
  }

  Future<void> _loadProfessionals() async {
    try {
      final users = await UserService()
          .watchAgendaProfessionals(_a.clinicId)
          .first;
      final available = selectableAgendaProfessionals(
        users,
        role: SessionManager().userRole,
        userId: SessionManager().userId,
      );
      if (!mounted) return;
      setState(() {
        _nextDentists = available;
        _professionalName = users
            .where((u) => u.id == _a.dentistId)
            .firstOrNull
            ?.name;
        _nextDentistId = selectedAgendaProfessional(_nextDentistId, available);
      });
      await _loadSuggestion();
    } catch (_) {
      if (mounted) {
        setState(
          () => _directoryError =
              'Profissionais indisponíveis. Reabra a ficha para tentar novamente.',
        );
      }
    }
  }

  Future<void> _loadOpenCharges() async {
    setState(() {
      _loadingCharges = true;
      _chargesError = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('financial')
          .where('clinicId', isEqualTo: _a.clinicId)
          .where('patientId', isEqualTo: _a.patientId)
          .get();
      final charges =
          snap.docs
              .map((d) => FinancialModel.fromMap(d.id, d.data()))
              .where(
                (c) =>
                    c.type == 'income' &&
                    c.status.toLowerCase() != 'cancelado' &&
                    !c.isPaid &&
                    !FinancialModel.isReplaced(c.status),
              )
              .toList()
            ..sort(
              (a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date),
            );
      if (mounted) {
        setState(() {
          _openCharges = charges;
          _selectedChargeId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _chargesError = 'Não foi possível conferir os lançamentos.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCharges = false);
    }
  }

  Future<void> _loadPackage() async {
    final scheduleId = _a.scheduleId;
    if (scheduleId == null) return;
    if (mounted) {
      setState(() {
        _loadingPackage = true;
        _packageError = null;
      });
    }
    try {
      final contract = await FirebaseFirestore.instance
          .collection('psychology_schedules')
          .doc(scheduleId)
          .get();
      if (contract.data()?['clinicId'] != _a.clinicId ||
          contract.data()?['patientId'] != _a.patientId) {
        throw StateError('Contrato incompatível.');
      }
      final sessions = await FirebaseFirestore.instance
          .collection('appointments')
          .where('clinicId', isEqualTo: _a.clinicId)
          .where('scheduleId', isEqualTo: scheduleId)
          .get();
      if (!mounted) return;
      setState(() {
        _contract = PsychologyScheduleModel.fromMap(
          scheduleId,
          contract.data()!,
        );
        _packageProgress = CarePackageProgress.fromSessions(
          sessions.docs
              .map((d) => AppointmentModel.fromMap(d.id, d.data()))
              .toList(),
          _a.date,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _packageError =
              'Não foi possível conferir o contrato terapêutico.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPackage = false);
    }
  }

  void _openPatient(PatientSection section) async {
    if (!await _flushBeforeNavigation() || !mounted) return;
    Navigator.push(
      context,
      openPatient(_a.patientId, _a.patientName, section: section),
    );
  }

  Future<void> _receiveExisting() async {
    if (_monthlyPackage || _loadingPackage || _packageError != null) return;
    final charge = _openCharges
        .where((c) => c.id == _selectedChargeId)
        .firstOrNull;
    if (charge == null) {
      toast(context, 'Escolha um lançamento em aberto.');
      return;
    }
    if (!await _flushBeforeNavigation() || !mounted) return;
    final remaining = charge.amount - charge.paidAmount;
    if (remaining <= 0) return;
    setState(() => _saving = true);
    try {
      await FinancialService().processPayment(
        originalTransaction: charge,
        payValue: remaining,
        method: _method,
        installments: 1,
        payerName: _a.patientName,
        payerCpf: '',
        dentistId: _a.dentistId,
        dentistName: _professionalName,
      );
      await _loadOpenCharges();
      if (mounted) {
        toast(context, 'Recebido ${formatBRL(remaining)}.', ok: true);
      }
    } catch (error) {
      if (mounted) toast(context, 'Erro ao receber: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadSuggestion([int? offset]) async {
    final generation = ++_suggestionGeneration;
    final did = _nextDentistId;
    if (did == null) return;
    setState(() {
      _loadingSuggestion = true;
      _suggestedFree = null;
    });
    try {
      final days = offset ?? careReturnOffsets(_psychology).first;
      final candidate = DateTime(
        _a.date.year,
        _a.date.month,
        _a.date.day + days,
        _a.date.hour,
        _a.date.minute,
      );
      final busy = await AppointmentService().getBusySlots(
        _a.clinicId,
        candidate,
        dentistId: did,
      );
      final grade = await clinicGrade(_a.clinicId);
      if (!mounted || generation != _suggestionGeneration) return;
      setState(() {
        _suggestedDate = candidate;
        _suggestedFree =
            careIntervalIsFree(candidate, _a.durationMinutes, busy) &&
            careIntervalFitsGrade(candidate, _a.durationMinutes, grade);
      });
    } catch (_) {
      if (mounted && generation == _suggestionGeneration) {
        setState(() => _suggestedDate = null);
      }
    } finally {
      if (mounted && generation == _suggestionGeneration) {
        setState(() => _loadingSuggestion = false);
      }
    }
  }

  Future<void> _safePickNext() async {
    try {
      await _pickNext();
    } catch (error) {
      if (mounted) {
        toast(
          context,
          'Não foi possível consultar a grade: $error',
          error: true,
        );
      }
    }
  }

  Future<void> _pickNext() async {
    if (_nextDentistId == null) {
      toast(context, 'Selecione o profissional.');
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final busy = await AppointmentService().getBusySlots(
      _a.clinicId,
      date,
      dentistId: _nextDentistId,
    );
    final grade = await clinicGrade(_a.clinicId);
    final free = grade.where((t) {
      final parts = t.split(':');
      final candidate = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return candidate.isAfter(DateTime.now()) &&
          careIntervalIsFree(candidate, _a.durationMinutes, busy) &&
          careIntervalFitsGrade(candidate, _a.durationMinutes, grade);
    }).toList();
    if (!mounted) return;
    if (free.isEmpty) {
      toast(context, 'Dia sem intervalo livre para este profissional.');
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Horários livres'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: free
                  .map(
                    (t) => ActionChip(
                      label: Text(t),
                      onPressed: () => Navigator.pop(ctx, t),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final parts = picked.split(':');
    setState(
      () => _nextDate = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      ),
    );
  }

  Future<void> _scheduleNext() async {
    if (_saving || _nextDate == null || _nextDentistId == null) {
      toast(context, 'Escolha profissional, data e horário.');
      return;
    }
    if (_psychology && (_loadingPackage || _packageError != null)) {
      toast(context, 'Aguarde a conferência do contrato antes de agendar.');
      return;
    }
    // Contratos recorrentes já possuem sessões futuras: não criar duplicata nem sessão sem vínculo.
    if (_monthlyPackage) {
      toast(context, 'Use as sessões já geradas ou gerencie o contrato.');
      return;
    }
    if (!await _flushBeforeNavigation() || !mounted) return;
    final tab = openBlankTab();
    setState(() => _saving = true);
    try {
      final busy = await AppointmentService().getBusySlots(
        _a.clinicId,
        _nextDate!,
        dentistId: _nextDentistId,
      );
      final grade = await clinicGrade(_a.clinicId);
      if (!careIntervalIsFree(_nextDate!, _a.durationMinutes, busy) ||
          !careIntervalFitsGrade(_nextDate!, _a.durationMinutes, grade)) {
        throw StateError(
          'Intervalo ocupado ou fora do expediente. Escolha outro.',
        );
      }
      if (_psychology) {
        try {
          tab?.close();
        } catch (_) {}
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PsychologyScheduleFormScreen(
              preSelectedDate: _nextDate,
              preSelectedTime: DateFormat('HH:mm').format(_nextDate!),
              preSelectedDayOfWeek: ClinicalCareDayView
                  .weekdays[_nextDate!.weekday - 1]
                  .split('-')
                  .first,
              preSelectedProfessionalId: _nextDentistId,
              initialData: {
                'patientId': _a.patientId,
                'patientName': _a.patientName,
                'startDate': Timestamp.fromDate(_nextDate!),
                'dayOfWeek': [
                  'Segunda',
                  'Terça',
                  'Quarta',
                  'Quinta',
                  'Sexta',
                  'Sábado',
                  'Domingo',
                ][_nextDate!.weekday - 1],
                'time': DateFormat('HH:mm').format(_nextDate!),
                'scheduleType': 'session',
              },
            ),
          ),
        );
      } else {
        await AppointmentService().add(
          AppointmentModel(
            id: '',
            patientId: _a.patientId,
            patientName: _a.patientName,
            date: _nextDate!,
            status: 'Aguardando Confirmação',
            procedure: _a.procedure,
            clinicId: _a.clinicId,
            dentistId: _nextDentistId,
            durationMinutes: _a.durationMinutes,
          ),
        );
        if ((_phone ?? '').isEmpty) {
          try {
            tab?.close();
          } catch (_) {}
        } else if (mounted) {
          await openWhatsAppSafe(
            context,
            tab,
            phone: _phone!,
            message: nextSessionText(
              patientName: _a.patientName,
              date: _nextDate!,
            ),
          );
        }
        if (mounted) toast(context, 'Próxima consulta agendada.', ok: true);
      }
      if (mounted) setState(() => _nextDate = null);
    } catch (error) {
      try {
        tab?.close();
      } catch (_) {}
      if (mounted) toast(context, 'Erro ao agendar: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _manageContract() async {
    if (_contract == null || !await _flushBeforeNavigation() || !mounted)
      return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PsychologyScheduleFormScreen(
          editScheduleId: _contract!.id,
          initialData: _contract!.toMap(),
          preSelectedProfessionalId: _contract!.dentistId,
        ),
      ),
    );
    if (mounted) await _loadPackage();
  }

  Widget _billing() => LayoutBuilder(
    builder: (context, constraints) {
      final charges = _chargeControls();
      final summary = _contractSummary();
      if (_psychology && _contract != null && constraints.maxWidth >= 560) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: summary),
            const SizedBox(width: 16),
            Expanded(child: charges),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_contract != null ||
              _loadingPackage ||
              _packageError != null) ...[
            summary,
            const SizedBox(height: 16),
          ],
          charges,
        ],
      );
    },
  );

  Widget _contractSummary() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: ClinicalAgendaStyle.background.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingPackage) const LinearProgressIndicator(),
        if (_packageError != null)
          Text(
            _packageError!,
            style: TextStyle(color: ClinicalAgendaStyle.danger),
          ),
        if (_contract != null) ...[
          CarePill(
            _monthlyPackage ? 'PACOTE VIGENTE' : 'SESSÃO AVULSA',
            active: true,
          ),
          const SizedBox(height: 12),
          Text(
            _monthlyPackage ? 'Contrato recorrente' : 'Atendimento avulso',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${_contract!.dayOfWeek} às ${_contract!.time}',
            style: TextStyle(
              color: ClinicalAgendaStyle.muted,
              fontSize: 12,
            ),
          ),
          if (_packageProgress != null && _monthlyPackage) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _packageProgress!.fraction,
                minHeight: 8,
                color: ClinicalCareStyle.accent,
                backgroundColor: ClinicalAgendaStyle.elevated,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_packageProgress!.finalized}/${_packageProgress!.planned} sessões finalizadas',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${_packageProgress!.remaining} previstas restantes',
              style: TextStyle(
                color: ClinicalCareStyle.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cobrança mensal conforme presença. Faltas com atestado seguem as regras do pacote.',
              style: TextStyle(
                color: ClinicalAgendaStyle.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _manageContract,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Gerenciar contrato'),
            ),
          ],
        ],
      ],
    ),
  );

  Widget _chargeControls() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: ClinicalAgendaStyle.elevated.withValues(alpha: .28),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingCharges) const LinearProgressIndicator(),
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: ClinicalCareStyle.accent,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Financeiro do paciente',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_chargesError != null) ...[
          Text(_chargesError!),
          TextButton(
            onPressed: _loadOpenCharges,
            child: const Text('Tentar novamente'),
          ),
        ] else if (!_loadingCharges && _openCharges.isEmpty)
          const Text(
            'Nada em aberto para este paciente. Novos lançamentos são criados na aba Pagamentos.',
          ),
        if (!_loadingCharges &&
            _openCharges.isNotEmpty &&
            !_monthlyPackage &&
            !_loadingPackage &&
            _packageError == null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedChargeId),
            initialValue: _selectedChargeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Lançamento existente',
            ),
            items: _openCharges
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.title} — ${formatBRL(c.amount - c.paidAmount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedChargeId = v),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: 'Meio de pagamento',
                  ),
                  items: _methods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (m) => setState(() => _method = m ?? 'Pix'),
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _receiveExisting,
                child: const Text('Receber lançamento'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openPatient(PatientSection.payments),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(
            _psychology
                ? 'Extrato financeiro / Pagamentos'
                : 'Lançar cobrança / Pagamentos',
          ),
        ),
      ],
    ),
  );

  Widget _scheduling() {
    if (_loadingPackage) return const LinearProgressIndicator();
    if (_packageError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_packageError!),
          TextButton(
            onPressed: _loadPackage,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    final next = _monthlyPackage ? _packageProgress?.next : null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ClinicalAgendaStyle.elevated.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_directoryError != null)
            Text(
              _directoryError!,
              style: TextStyle(color: ClinicalAgendaStyle.danger),
            ),
          if (_monthlyPackage) ...[
            Text(
              next == null
                  ? 'Nenhuma sessão futura encontrada neste contrato.'
                  : 'Próxima sessão já agendada: ${DateFormat('dd/MM HH:mm').format(next.date)}',
            ),
            const SizedBox(height: 8),
            Text(
              'As sessões do pacote são geradas pelo contrato; não será criada uma cópia ao finalizar.',
              style: TextStyle(color: ClinicalAgendaStyle.muted, fontSize: 12),
            ),
            TextButton(
              onPressed: () => _openPatient(PatientSection.registration),
              child: const Text('Consultar ficha do paciente'),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(_nextDentistId),
              initialValue: _nextDentists.any((d) => d.id == _nextDentistId)
                  ? _nextDentistId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Profissional responsável',
              ),
              items: _nextDentists
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _nextDentistId = v;
                  _nextDate = null;
                });
                _loadSuggestion();
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in careReturnOffsets(_psychology))
                  OutlinedButton(
                    onPressed: _saving || _nextDentistId == null
                        ? null
                        : () => _loadSuggestion(days),
                    child: Text(
                      _psychology
                          ? (days == 7 ? 'Semanal' : 'Quinzenal')
                          : 'Em $days dias',
                    ),
                  ),
                OutlinedButton(
                  onPressed: _saving ? null : _safePickNext,
                  child: const Text('Personalizado / Ver grade livre'),
                ),
              ],
            ),
            if (_loadingSuggestion)
              const LinearProgressIndicator()
            else if (_suggestedDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Sugestão: ${DateFormat('dd/MM HH:mm').format(_suggestedDate!)} • ${_suggestedFree == true ? 'Livre' : 'Ocupado'}',
                    ),
                    TextButton(
                      onPressed: _suggestedFree == true && !_saving
                          ? () => setState(() => _nextDate = _suggestedDate)
                          : null,
                      child: const Text('Selecionar horário'),
                    ),
                  ],
                ),
              ),
            if (_nextDate != null)
              Text(
                'Selecionado: ${DateFormat('dd/MM HH:mm').format(_nextDate!)}',
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _scheduleNext,
              icon: const Icon(Icons.event_available),
              label: Text(
                _psychology
                    ? 'Agendar sessão avulsa'
                    : 'Agendar e chamar no WhatsApp',
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: (!_dirty && !_saving && !_draftSaving) || widget.onClose == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: _recordError != null
        ? CareSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_recordError!),
                TextButton(
                  onPressed: _loadRecord,
                  child: const Text('Tentar novamente'),
                ),
                if (widget.onClose != null)
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Fechar ficha'),
                  ),
              ],
            ),
          )
        : ClinicalCareVisitView(
            appointment: _a,
            psychology: _psychology,
            detailsController: _detailsCtrl,
            markers: _markers,
            templates: attendanceTemplates(
              _psychology ? 'psychology' : 'dental',
            ),
            onMarker: (text) {
              if (_loadingDraft) return;
              setState(() {
                if (!_markers.add(text)) _markers.remove(text);
              });
              _changed();
            },
            onSaveDraft: _saveDraft,
            onSaveEvolution: () => _saveEvolution(),
            onFinalize: () => _saveEvolution(finalize: true),
            onStartPause: _startPause,
            onOpenRecord: () => _openPatient(PatientSection.record),
            onClose: widget.onClose == null ? null : _close,
            billing: _billing(),
            scheduling: _scheduling(),
            draftStatus: _draftStatus,
            saving: _saving || _loadingDraft,
            evolutionSaved: _evolutionSaved,
            alerts: [..._alerts, if (_contextError != null) _contextError!],
            professionalName: _professionalName,
            status: _status,
          ),
  );
}
