import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html; 

import 'agenda_cell_factory.dart';
import 'agenda_form_screen.dart';
import '../patients/patient_details_screen.dart';

import '../../ui/app_theme.dart';
import 'agenda_skeleton.dart';
import '../../services/session_manager.dart';
import '../../services/portal_mirror.dart';
import '../care/remarcar_dialog.dart';
import '../../services/month_agenda_cache.dart';
import '../../services/user_service.dart';
import '../../services/treatment_service.dart';
import '../../services/clinical_record_service.dart'; 
import '../../services/patient_service.dart'; 
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/block_interval.dart';
import '../../utils/display.dart';

class AgendaManagerScreen extends StatefulWidget {
  const AgendaManagerScreen({super.key});

  @override
  State<AgendaManagerScreen> createState() => _AgendaManagerScreenState();
}

class _AgendaManagerScreenState extends State<AgendaManagerScreen> {
  // Services
  final MonthAgendaCache _monthCache = MonthAgendaCache();
  final UserService _userService = UserService();
  final TreatmentService _treatmentService = TreatmentService();
  final ClinicalRecordService _clinicalRecordService = ClinicalRecordService();
  final PatientService _patientService = PatientService();

  DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  final List<String> _timeSlots = [];
  final double _rowHeight = 32.0;
  final double _headerHeight = 36.0;

  // Filtros
  String? _selectedDentistId;
  List<DropdownMenuItem<String>> _dentistItems = [];
  bool _isLoadingDentists = false;
  bool _shouldShowFilter = false;

  @override
  void initState() {
    super.initState();
    _generateTimeSlots();
    _currentWeekStart = DateTime(_currentWeekStart.year, _currentWeekStart.month, _currentWeekStart.day);
    _checkRoleAndFetchDentists();
  }

  void _checkRoleAndFetchDentists() async {
    final role = SessionManager().userRole?.toLowerCase().trim();
    final clinicId = SessionManager().currentClinicId;

    // Janela de slots do portal (14 dias, fim de semana incluso):
    // throttled em 6h no service — 1 leitura na maioria das vezes.
    if (clinicId != null) {
      PortalMirrorSync.ensureWindow(clinicId);
    }

    if ((role == 'recepcionista' || role == 'owner') && clinicId != null) {
      setState(() {
        _shouldShowFilter = true;
        _isLoadingDentists = true;
      });

      List<UserModel> dentists = await _userService.getDentistsForClinic(clinicId);

      if (mounted) {
        setState(() {
          _dentistItems = dentists.map((u) => DropdownMenuItem(
            value: u.id,
            child: Text(u.name, style: const TextStyle(fontSize: 14)),
          )).toList();
          
          if (_dentistItems.isNotEmpty) {
             if (_selectedDentistId == null || !dentists.any((u) => u.id == _selectedDentistId)) {
               _selectedDentistId = dentists.first.id;
             }
          }
          _isLoadingDentists = false;
        });
      }
    }
  }

  void _generateTimeSlots() {
    int startMin = 8 * 60 + 30; // 08:30
    int endMin = 20 * 60;       // 20:00
    for (int i = startMin; i <= endMin; i += 30) {
      _timeSlots.add("${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}");
    }
  }

  void _changeWeek(int days) {
    setState(() => _currentWeekStart = _currentWeekStart.add(Duration(days: days)));
  }

  @override
  void dispose() {
    _monthCache.dispose();
    super.dispose();
  }

  // --- BLOQUEIO POR INTERVALO (1 doc; paciente primeiro, fusão, idempotência) ---

  String _hhmm(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  Future<void> _applyBlockInterval({
    required DateTime targetDate,
    required TimeOfDay start,
    required TimeOfDay end,
    required String label,
  }) async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;
    final dentistId = _selectedDentistId;
    if (dentistId == null) {
      if (mounted) toast(context, "Selecione o profissional para bloquear.");
      return;
    }

    final base = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final s = snapDown(
        base.add(Duration(hours: start.hour, minutes: start.minute)));
    final e =
        snapUp(base.add(Duration(hours: end.hour, minutes: end.minute)));
    if (!e.isAfter(s)) {
      if (mounted) toast(context, "Intervalo inválido.", error: true);
      return;
    }

    // Mesma forma da liberação (sem índice novo: filtra dentista no cliente).
    final dayStart = DateTime(base.year, base.month, base.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    late QuerySnapshot dayDocs;
    try {
      dayDocs = await FirebaseFirestore.instance
          .collection('appointments')
          .where('clinicId', isEqualTo: clinicId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThan: Timestamp.fromDate(dayEnd))
          .get();
    } catch (err) {
      if (mounted) toast(context, "Erro ao ler agenda: $err", error: true);
      return;
    }

    final blocks = <QueryDocumentSnapshot>[];
    final real = <BlockSpan>[];
    for (final doc in dayDocs.docs) {
      final m = doc.data() as Map<String, dynamic>;
      if ('${m['dentistId'] ?? ''}' != dentistId) continue;
      final d = (m['date'] as Timestamp?)?.toDate();
      if (d == null) continue;
      final dur = (m['durationMinutes'] as num?)?.toInt() ?? 30;
      final st = '${m['status'] ?? ''}';
      if (st == 'Bloqueado') {
        blocks.add(doc);
      } else if (st.toLowerCase() != 'cancelado') {
        real.add((start: d, end: d.add(Duration(minutes: dur))));
      }
    }

    // Regra 1: paciente primeiro — com consulta no meio, sem bloqueio.
    final conflicts = findOverlaps(s, e, real);
    if (conflicts.isNotEmpty) {
      final times = conflicts.map((c) => _hhmm(c.start)).join(', ');
      if (mounted) {
        toast(context,
            "Não bloqueado: há agendamento em $times. Escolha outro intervalo.",
            error: true);
      }
      return;
    }

    // Regras 2+3: funde sobrepostos/adjacentes; repetido = sem escrita.
    final overlapped = <QueryDocumentSnapshot>[];
    final coverage = <BlockSpan>[(start: s, end: e)];
    for (final b in blocks) {
      final m = b.data() as Map<String, dynamic>;
      final d = (m['date'] as Timestamp).toDate();
      final dur = (m['durationMinutes'] as num?)?.toInt() ?? 30;
      final bs = d;
      final be = d.add(Duration(minutes: dur));
      if (touchesOrOverlaps(s, e, bs, be)) {
        overlapped.add(b);
        coverage.add((start: bs, end: be));
      }
    }
    final u = unionAll(coverage);
    if (overlapped.length == 1) {
      final m = overlapped.first.data() as Map<String, dynamic>;
      final d = (m['date'] as Timestamp).toDate();
      final dur = (m['durationMinutes'] as num?)?.toInt() ?? 30;
      if (isNoOp(
        mergedStart: u.start,
        mergedEnd: u.end,
        overlappedCount: 1,
        existingStart: d,
        existingEnd: d.add(Duration(minutes: dur)),
      )) {
        if (mounted) toast(context, "Intervalo já bloqueado.");
        return;
      }
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final b in overlapped) {
        batch.delete(b.reference);
      }
      final newDocRef =
          FirebaseFirestore.instance.collection('appointments').doc();
      batch.set(
          newDocRef,
          AppointmentModel(
            id: newDocRef.id,
            patientId: 'BLOCKED_SLOT',
            patientName: 'BLOQUEADO',
            date: u.start,
            status: 'Bloqueado',
            procedure: label,
            clinicId: clinicId,
            dentistId: dentistId,
            durationMinutes: u.end.difference(u.start).inMinutes,
          ).toMap());
      await batch.commit();
      // Espelho de slots (best-effort): intervalo sai dos livres.
      await PortalMirrorSync.adjustSlots(
        clinicId: clinicId,
        byDentist: {dentistId: expandSlots(u.start, u.end)},
        occupy: true,
      );
      if (mounted) {
        toast(context, "$label aplicado (${_hhmm(u.start)}–${_hhmm(u.end)}).");
      }
    } catch (err) {
      if (mounted) toast(context, "Erro ao bloquear: $err", error: true);
    }
  }

  Future<void> _unblockDay(DateTime targetDate) async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;

    DateTime start = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0);
    DateTime end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);

    try {
      // Busca APENAS os agendamentos com status 'Bloqueado'
      var snapshot = await FirebaseFirestore.instance.collection('appointments')
          .where('clinicId', isEqualTo: clinicId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'Bloqueado') 
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) toast(context, "Nenhum bloqueio encontrado para esta data.");
        return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int deleteCount = 0;
      final freedByDentist = <String, List<DateTime>>{};

      for (var doc in snapshot.docs) {
        String? docDentistId = doc.data().containsKey('dentistId') ? doc['dentistId'] : null;
        
        if (_selectedDentistId != null && docDentistId != null && docDentistId != _selectedDentistId) {
          continue; 
        }

        final d = (doc.data()['date'] as Timestamp?)?.toDate();
        if (d != null && (docDentistId ?? '').isNotEmpty) {
          freedByDentist
              .putIfAbsent(docDentistId!, () => [])
              .add(d);
        }
        batch.delete(doc.reference);
        deleteCount++;
      }

      if (deleteCount > 0) {
        await batch.commit();
        // Espelho de slots (best-effort): liberados voltam aos livres.
        await PortalMirrorSync.adjustSlots(
          clinicId: clinicId,
          byDentist: freedByDentist,
          occupy: false,
        );
        if (mounted) toast(context, "Dia liberado com sucesso!");
      } else {
        if (mounted) toast(context, "Nenhum bloqueio corresponde ao filtro atual.");
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao liberar: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showManagementMenu() {
    DateTime targetDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Gestão de Agenda", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text("Data: ${formatDateFull(targetDate)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: targetDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setStateModal(() => targetDate = picked);
                      },
                    )
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined, color: Colors.orange),
                  title: const Text("Bloquear Manhã"),
                  subtitle: const Text("08:30 - 12:00"),
                  onTap: () {
                    Navigator.pop(context);
                    _applyBlockInterval(
                      targetDate: targetDate,
                      start: const TimeOfDay(hour: 8, minute: 30),
                      end: const TimeOfDay(hour: 12, minute: 0),
                      label: "Manhã Fechada",
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.nights_stay_outlined, color: Colors.deepPurple),
                  title: const Text("Bloquear Tarde"),
                  subtitle: const Text("13:00 - 18:00"),
                  onTap: () {
                    Navigator.pop(context);
                    _applyBlockInterval(
                      targetDate: targetDate,
                      start: const TimeOfDay(hour: 13, minute: 0),
                      end: const TimeOfDay(hour: 18, minute: 0),
                      label: "Tarde Fechada",
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text("Bloquear Dia Todo"),
                  subtitle: const Text("08:30 - 20:00"),
                  onTap: () {
                    Navigator.pop(context);
                    _applyBlockInterval(
                      targetDate: targetDate,
                      start: const TimeOfDay(hour: 8, minute: 30),
                      // Fim exclusivo: 20:30 p/ cobrir o slot das 20:00.
                      end: const TimeOfDay(hour: 20, minute: 30),
                      label: "Dia Fechado",
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule, color: Colors.blue),
                  title: const Text("Bloquear intervalo"),
                  subtitle: const Text("Ex.: 12:00 - 14:00"),
                  onTap: () async {
                    Navigator.pop(context);
                    final s = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 12, minute: 0),
                    );
                    if (s == null || !mounted) return;
                    final e = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 14, minute: 0),
                    );
                    if (e == null) return;
                    await _applyBlockInterval(
                      targetDate: targetDate,
                      start: s,
                      end: e,
                      label: "Intervalo fechado",
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_open, color: Colors.green),
                  title: const Text("Liberar Dia"),
                  subtitle: const Text("Remove apenas os bloqueios"),
                  onTap: () {
                    Navigator.pop(context);
                    _unblockDay(targetDate);
                  },
                ),
              ],
            ),
            ),
          );
        }
      ),
    );
  }

  // --- MÉTODOS ORIGINAIS (MANTIDOS) ---

  void _launchWhatsApp(AppointmentModel appt) async {
    // Web: abre a aba no gesto (síncrono) p/ o bloqueador de pop-up não
    // matar; preenche a URL após buscar o telefone.
    html.WindowBase? blankTab;
    if (kIsWeb) {
      try {
        blankTab = html.window.open('', '_blank');
      } catch (e) { /* ignore */ }
    }
    String? phoneRaw;
    try {
      toast(context, "Buscando contato...", duration: const Duration(milliseconds: 500));
      final patientDoc = await FirebaseFirestore.instance.collection('patients').doc(appt.patientId).get();
      if (patientDoc.exists) {
        final data = patientDoc.data();
        phoneRaw = data?['phone'] ?? data?['celular'] ?? data?['whatsapp'];
      }
    } catch (e) { /* ignore */ }
    
    if (phoneRaw == null || phoneRaw.isEmpty) {
      try { blankTab?.close(); } catch (e) { /* ignore */ }
      if (mounted) toast(context, "Telefone do paciente não encontrado no cadastro.");
      return;
    }
    String phone = phoneRaw.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length < 10) {
       try { blankTab?.close(); } catch (e) { /* ignore */ }
       if (mounted) toast(context, "Número de telefone inválido.");
       return;
    }
    if (!phone.startsWith('55')) phone = '55$phone'; 
    String link = "https://nexosaude.web.app/confirmar.html?id=${appt.id}";
    String message = "Olá ${appt.patientName}, por favor confirme sua consulta para o dia ${formatDateAs(appt.date)} clicando neste link: $link";
    final waUrl = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    if (blankTab != null) {
      try {
        blankTab.location.href = waUrl;
        return;
      } catch (e) { /* cai p/ launchUrl */ }
    }
    final url = Uri.parse(waUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) toast(context, "Não foi possível abrir o WhatsApp.");
    }
  }

  void _showCancellationDialog(AppointmentModel appt) {
    final reasonCtrl = TextEditingController();
    String cancellationSource = 'Paciente'; 
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text("Cancelar Agendamento"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Paciente: ${appt.patientName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  const Text("Quem solicitou o cancelamento?", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("Paciente", style: TextStyle(fontSize: 14)),
                          value: 'Paciente',
                          groupValue: cancellationSource,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          activeColor: Colors.red,
                          onChanged: (val) => setStateModal(() => cancellationSource = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("Clínica/Dr(a)", style: TextStyle(fontSize: 14)),
                          value: 'Clínica',
                          groupValue: cancellationSource,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          activeColor: Colors.red,
                          onChanged: (val) => setStateModal(() => cancellationSource = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("Motivo do Cancelamento:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: "Ex: Imprevisto, Doença, Reagendamento...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12)
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Obs: O horário ficará livre para novos agendamentos.",
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Voltar")),
                ElevatedButton(
                  onPressed: () async {
                    if (reasonCtrl.text.isEmpty) {
                      toast(context, "Informe o motivo.");
                      return;
                    }
                    final String userName = SessionManager().userName ?? "Usuário";
                    final String reason = reasonCtrl.text.trim();
                    await FirebaseFirestore.instance.collection('appointments').doc(appt.id).update({
                      'status': 'Cancelado',
                      'cancelledBy': userName,
                      'cancellationReason': reason,
                      'cancellationSource': cancellationSource,
                      'cancelledAt': FieldValue.serverTimestamp(),
                    });
                    await _clinicalRecordService.add({
                      'clinicId': appt.clinicId,
                      'treatmentId': null, 
                      'patientId': appt.patientId,
                      'patientName': appt.patientName,
                      'procedureName': 'Cancelamento de Consulta',
                      'description': "Cancelamento solicitado por: $cancellationSource.\nMotivo: $reason\nRegistrado por: $userName",
                      'dentistName': userName, 
                      'date': DateTime.now(),
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      toast(context, "Agendamento cancelado com sucesso.");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text("CONFIRMAR"),
                )
              ],
            );
          }
        );
      },
    );
  }

  // --- MENU DE OPÇÕES (COM SCROLL) ---
  void _showAppointmentOptions(AppointmentModel appt, int concurrentCount) {
    if (appt.status == 'Bloqueado') {
      showModalBottomSheet(context: context, builder: (ctx) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.green),
            title: const Text("Desbloquear Horário"),
            subtitle: Text(appt.durationMinutes > 30
                ? "Libera o intervalo todo"
                : "Tornar este horário disponível novamente"),
            onTap: () async {
              await FirebaseFirestore.instance.collection('appointments').doc(appt.id).delete();
              Navigator.pop(ctx);
            },
          )
        ]);
      });
      return;
    }

    bool isConfirmed = appt.status == 'Confirmado';
    bool isCancelled = appt.status == 'Cancelado';
    bool isFinished = appt.status == 'Finalizado';
    
    // Regra do Encaixe: Habilitado apenas se houver somente 1 evento (o próprio)
    bool canFitIn = concurrentCount == 1 && !isCancelled && !isFinished;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView( 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ListTile(
                  leading: CircleAvatar(child: Text(appt.patientName.isNotEmpty ? appt.patientName.substring(0,1) : '?')),
                  title: Text(appt.patientName, style: TextStyle(fontWeight: FontWeight.bold, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                  subtitle: Text(appt.status.toLowerCase() == 'remarcar' &&
                          appt.proposedDate != null
                      ? "Atual ${formatDateDash(appt.date)} → Proposto ${formatDateTimeShort(appt.proposedDate!)}"
                      : "${formatDateDash(appt.date)} • ${appt.status}"),
                ),

                FutureBuilder<Map<String, dynamic>>(
                  future: _patientService.getPatientRiskProfile(appt.patientId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    
                    final risk = snapshot.data!;
                    if (risk['level'] == 'green') return const SizedBox();
                    
                    bool isRed = risk['level'] == 'red';
                    Color color = isRed ? Colors.red : Colors.orange;
                    String title = isRed ? "ALTO RISCO DE NO-SHOW" : "Atenção ao Histórico";
                    String msg = "Paciente faltou/cancelou ${risk['missed']} vezes recentemente.";

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
                                Text(msg, style: TextStyle(fontSize: 12)),
                                if (isRed)
                                  const Text("Recomendado confirmar com antecedência.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),

                const Divider(),

                // Pedido de remarcação do portal: decide aqui.
                if (appt.status.toLowerCase() == 'remarcar' &&
                    appt.proposedDate != null)
                  ListTile(
                    leading:
                        const Icon(Icons.event_repeat, color: Colors.orange),
                    title: const Text("Decidir remarcação",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                    subtitle: Text(
                        "Propôs ${formatDateTimeShort(appt.proposedDate!)}"),
                    onTap: () {
                      Navigator.pop(context);
                      showRemarcarDialog(context, appt);
                    },
                  ),

                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: const Text("Abrir Paciente"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => PatientDetailsScreen(
                      patientId: appt.patientId,
                      patientName: appt.patientName,
                    )));
                  },
                ),

                if (!isConfirmed && !isCancelled && !isFinished && appt.status.toLowerCase() != 'remarcar')
                ListTile(
                  leading: const Icon(Icons.thumb_up_alt, color: Colors.teal),
                  title: const Text("Confirmar Presença (Manual)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  subtitle: const Text("Paciente ligou ou confirmou no balcão"),
                  onTap: () async {
                    await FirebaseFirestore.instance.collection('appointments').doc(appt.id).update({
                      'status': 'Confirmado'
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      toast(context, "Presença confirmada com sucesso!");
                    }
                  },
                ),
                
                if (isCancelled) ...[
                   ListTile(
                    leading: const Icon(Icons.info, color: Colors.orange),
                    title: const Text("Ver Detalhes do Cancelamento"),
                    subtitle: const Text("Motivo e Responsável"),
                    onTap: () {
                       Navigator.pop(context);
                       _showCancellationDetails(appt);
                    },
                  ),
                ] else if (isFinished) ...[
                  ListTile(
                    leading: const Icon(Icons.lock, color: Colors.grey),
                    title: const Text("Atendimento Finalizado"),
                    subtitle: const Text("Este agendamento já foi concluído."),
                    onTap: null, 
                  ),
                ] else ...[
                  if (!isConfirmed)
                    ListTile(
                      leading: const Icon(Icons.chat, color: Colors.green),
                      title: const Text("Enviar Confirmação (WhatsApp)"),
                      onTap: () {
                        Navigator.pop(context);
                        _launchWhatsApp(appt);
                      },
                    ),

                  if (isConfirmed)
                    ListTile(
                      leading: const Icon(Icons.check_circle, color: AppColors.primary),
                      title: const Text("Finalizar Atendimento (Evolução)"),
                      onTap: () {
                        Navigator.pop(context);
                        _showFinishAppointmentDialog(appt);
                      },
                    ),
                  
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blueGrey),
                    title: const Text("Editar Agendamento"),
                    onTap: () {
                      Navigator.pop(context);
                      Map<String, dynamic> editData = appt.toMap();
                      if (appt.dentistId != null) editData['dentistId'] = appt.dentistId;
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AgendaFormScreen(
                        editAppointmentId: appt.id, 
                        initialData: editData
                      )));
                    },
                  ),

                  // OPÇÃO DE ENCAIXE
                  ListTile(
                    leading: Icon(Icons.group_add, color: canFitIn ? Colors.deepPurple : Colors.grey),
                    title: Text("Realizar Encaixe", style: TextStyle(color: canFitIn ? AppColors.textPrimary : Colors.grey)),
                    subtitle: canFitIn 
                        ? const Text("Adicionar outro paciente neste horário")
                        : const Text("Horário já possui encaixe (Máx 2)"),
                    enabled: canFitIn,
                    onTap: canFitIn ? () {
                      Navigator.pop(context);
                      Map<String, dynamic> preFill = {
                        'date': Timestamp.fromDate(appt.date),
                        'dentistId': appt.dentistId
                      };
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AgendaFormScreen(initialData: preFill)));
                    } : null,
                  ),

                  const Divider(),
                  
                  ListTile(
                    leading: const Icon(Icons.cancel, color: Colors.red),
                    title: const Text("Cancelar Agendamento", style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCancellationDialog(appt);
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showCancellationDetails(AppointmentModel appt) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('appointments').doc(appt.id).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return AlertDialog(
                title: const Text("Erro"),
                content: const Text("Não foi possível carregar os detalhes."),
                actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))],
              );
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String reason = data['cancellationReason'] ?? 'Motivo não informado.';
            final String byUser = data['cancelledBy'] ?? 'Usuário desconhecido';
            final Timestamp? at = data['cancelledAt'];
            final String dateStr = at != null ? formatDateTimeFull(at.toDate()) : 'Data desconhecida';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.block, color: Colors.red[300]),
                  const SizedBox(width: 10),
                  const Text("Agendamento Cancelado", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("MOTIVO:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red)),
                        const SizedBox(height: 4),
                        Text(reason, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500 )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontSize: 13), children: [const TextSpan(text: "Cancelado por: ", style: TextStyle(color: Colors.grey)), TextSpan(text: byUser, style: const TextStyle(fontWeight: FontWeight.bold))]))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text("Em: $dateStr", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR", style: TextStyle(fontWeight: FontWeight.bold)))],
            );
          }
        );
      }
    );
  }

  void _showFinishAppointmentDialog(AppointmentModel appt) {
    final noteCtrl = TextEditingController();
    String? selectedTreatmentId;
    String? selectedProcedureName;
    List<dynamic> proceduresOfPlan = [];
    bool isAbsent = false;
    bool hasCertificate = false;
    // Psicologia: sem escolha de procedimento — só descrição (usa o vínculo do pacote).
    final bool isPsychology =
        appt.procedure.contains('Psicologia') || appt.scheduleId != null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text("Finalizar Atendimento"),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Paciente: ${appt.patientName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      const Text("Situação:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text("Realizado", style: TextStyle(fontSize: 13)),
                              value: false,
                              groupValue: isAbsent,
                              activeColor: Colors.green,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) => setStateModal(() {
                                isAbsent = val!;
                                if (!isAbsent) hasCertificate = false;
                              }),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text("Não Compareceu", style: TextStyle(fontSize: 13)),
                              value: true,
                              groupValue: isAbsent,
                              activeColor: Colors.red, 
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) => setStateModal(() => isAbsent = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (!isAbsent && !isPsychology) ...[
                        StreamBuilder<QuerySnapshot>(
                          stream: _treatmentService.getPlansStream(appt.patientId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const LinearProgressIndicator();
                            final plans = snapshot.data!.docs.where((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              return d['status'] == 'active';
                            }).toList();
                            if (plans.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.orange[50],
                                child: const Text("Nenhum plano ativo. Será um atendimento avulso.", style: TextStyle(fontSize: 12, color: Colors.orange)),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              value: selectedTreatmentId,
                              isExpanded: true,
                              hint: const Text("Vincular ao Tratamento"),
                              items: plans.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final date = (data['startDate'] as Timestamp).toDate();
                                String label = "Iniciado em ${formatDateShortYear(date)}";
                                return DropdownMenuItem(
                                  value: doc.id,
                                  onTap: () {
                                    setStateModal(() {
                                      proceduresOfPlan = List.from(data['items'] ?? []);
                                      selectedProcedureName = null; 
                                    });
                                  },
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: (val) => setStateModal(() => selectedTreatmentId = val),
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                            );
                          }
                        ),
                        const SizedBox(height: 15),
                        if (selectedTreatmentId != null) ...[
                          DropdownButtonFormField<String>(
                            value: selectedProcedureName,
                            isExpanded: true,
                            hint: const Text("Qual procedimento realizado?"),
                            items: proceduresOfPlan.map((item) {
                              String name = item['name'] ?? 'Procedimento';
                              return DropdownMenuItem(value: name, child: Text(name));
                            }).toList(),
                            onChanged: (val) => setStateModal(() => selectedProcedureName = val),
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                          ),
                          const SizedBox(height: 15),
                        ],
                      ],
                      if (isAbsent) ...[
                        CheckboxListTile(
                          title: const Text("Apresentou Atestado",
                              style: TextStyle(fontSize: 13)),
                          subtitle: const Text(
                              "Falta com atestado abate do pacote",
                              style: TextStyle(fontSize: 11)),
                          value: hasCertificate,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) => setStateModal(
                              () => hasCertificate = val ?? false),
                        ),
                      ],
                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: isAbsent ? "Motivo da Falta (Opcional)" : "Evolução Clínica / O que foi feito?",
                          border: const OutlineInputBorder(),
                          hintText: isAbsent ? "Ex: Esqueceu, imprevisto..." : "Ex: Realizado restauração..."
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton.icon(
                  icon: Icon(isAbsent ? Icons.person_off : Icons.check),
                  label: Text(isAbsent ? "REGISTRAR FALTA" : "FINALIZAR & SALVAR"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAbsent ? Colors.orange : Colors.green, 
                    foregroundColor: Colors.white
                  ),
                  onPressed: () async {
                    if (!isAbsent && noteCtrl.text.isEmpty) {
                      toast(context, "Descreva o que foi feito.");
                      return;
                    }
                    String dentistName = 'Dr(a). Responsável';
                    if (appt.dentistId != null) {
                       try {
                         final userDoc = await FirebaseFirestore.instance.collection('users').doc(appt.dentistId).get();
                         if (userDoc.exists) {
                           dentistName = userDoc.data()?['name'] ?? 'Dentista';
                         }
                       } catch (e) { /* ignore */ }
                    }
                    final clinicId = SessionManager().currentClinicId;
                    final bool certificate = isAbsent && hasCertificate;
                    String finalProcedureName = isAbsent
                        ? 'Paciente Não Compareceu'
                        : (isPsychology
                            ? appt.procedure
                            : (selectedProcedureName ?? 'Atendimento Geral'));
                    String finalDescription = isAbsent
                        ? "Paciente faltou ao agendamento."
                            "${certificate ? "\nApresentou atestado." : ""}"
                            "\nObs: ${noteCtrl.text}"
                        : noteCtrl.text.trim();
                    await _clinicalRecordService.add({
                      'clinicId': clinicId,
                      'treatmentId': isAbsent
                          ? null
                          : (isPsychology ? appt.planId : selectedTreatmentId),
                      'patientId': appt.patientId,
                      'patientName': appt.patientName,
                      'procedureName': finalProcedureName,
                      'description': finalDescription,
                      'dentistName': dentistName,
                      'date': DateTime.now(),
                    });
                    await FirebaseFirestore.instance.collection('appointments').doc(appt.id).update({
                      'status': 'Finalizado',
                      'attendanceStatus': isAbsent ? 'Missed' : 'Attended',
                      'hasMedicalCertificate': certificate,
                    });
                    if (mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isAbsent ? "Falta registrada no prontuário!" : "Atendimento finalizado com sucesso!")
                    ));
                  },
                )
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime weekEnd = _currentWeekStart.add(const Duration(days: 7));
    final clinicId = SessionManager().currentClinicId;
    final userRole = SessionManager().userRole?.toLowerCase().trim();
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    if (clinicId == null) return const Center(child: Text("Erro: Sessão inválida"));

    // Janela mensal em cache (anterior/atual/proximo). Idempotente e
    // cobre troca de semana E troca de clinica (limpa e recomeca).
    _monthCache.ensureWindow(clinicId, _currentWeekStart);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Agenda Semanal",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManagementMenu,
        icon: const Icon(Icons.edit_calendar, color: Colors.white),
        label: const Text("Gestão", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.accent,
      ),

      body: Column(
        children: [
          if (_shouldShowFilter)
            Container(
              width: double.infinity, margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.1))),
              child: _isLoadingDentists 
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      isExpanded: true, value: _selectedDentistId,
                      items: _dentistItems,
                      onChanged: (val) => setState(() => _selectedDentistId = val),
                      hint: const Text("Selecione o Profissional"),
                    ),
                  ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 6))]),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeWeek(-7)), 
                Expanded(child: Column(children: [
                  Text("Semana", style: AppTextStyles.caption.copyWith(fontSize: 12)), 
                  Text("${formatDateShort(_currentWeekStart)}  –  ${formatDateShort(weekEnd.subtract(const Duration(days: 1)))}", style: AppTextStyles.subtitle.copyWith(fontSize: 13))
                ])), 
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeWeek(7))
              ]),
            ),
          ),
          
          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<Map<String, List<AppointmentModel>>>(
              stream: _monthCache.stream,
              builder: (context, snapshot) {
                // Skeleton só se o mês visível ainda não chegou do cache;
                // erro explícito em vez de loader infinito.
                final monthKey =
                    MonthAgendaCache.keyOf(_currentWeekStart);
                if (!_monthCache.cachedMonths.contains(monthKey) &&
                    !snapshot.hasData) {
                  return const AgendaSkeleton();
                }
                // Filtro de profissional ainda resolvendo: segura a grade no
                // skeleton em vez de exibir tudo sem filtro e trocar depois.
                // (Lista vazia = sem o que filtrar: mostra a grade normal.)
                if (_shouldShowFilter && _isLoadingDentists) {
                  return const AgendaSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Erro ao carregar agenda: ${snapshot.error}"));
                }

                // Semana visível filtrada do cache mensal (zero leitura
                // quando o mês já está em memória).
                Map<String, List<AppointmentModel>> appointmentsMap = {};

                for (var appt
                    in _monthCache.forWeek(_currentWeekStart, weekEnd)) {
                  if (userRole == 'dentista' && appt.dentistId != currentUserUid) continue;
                  if (_shouldShowFilter && _selectedDentistId != null) {
                    if (appt.dentistId != null && appt.dentistId != _selectedDentistId) continue;
                  }

                  int slots = (appt.durationMinutes / 30).ceil();
                  for (int i = 0; i < slots; i++) {
                    DateTime slotTime = appt.date.add(Duration(minutes: 30 * i));
                    String key = "${slotTime.year}-${slotTime.month}-${slotTime.day}-${slotTime.hour.toString().padLeft(2, '0')}:${slotTime.minute.toString().padLeft(2, '0')}";
                    
                    appointmentsMap.putIfAbsent(key, () => []);
                    appointmentsMap[key]!.add(appt);
                  }
                }

                return SingleChildScrollView(
                  child: Table(
                    columnWidths: const {0: FixedColumnWidth(45)},
                    defaultColumnWidth: const FlexColumnWidth(1),
                    border: TableBorder(horizontalInside: BorderSide(color: AppColors.borderSoft, width: 0.5), verticalInside: BorderSide.none),
                    children: [
                      TableRow(children: [
                        SizedBox(height: _headerHeight, child: const Center(child: Icon(Icons.access_time, size: 16))), 
                        ...List.generate(6, (index) { 
                          DateTime day = _currentWeekStart.add(Duration(days: index)); 
                          return Container(
                            height: _headerHeight, alignment: Alignment.center, 
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(_getWeekDayName(day.weekday), style: AppTextStyles.caption.copyWith(fontSize: 12)), 
                              Text("${day.day}", style: AppTextStyles.caption.copyWith(fontSize: 12))
                            ])
                          ); 
                        })
                      ]),
                      
                      ..._timeSlots.map((time) => TableRow(children: [
                        Container(height: _rowHeight, alignment: Alignment.topCenter, padding: const EdgeInsets.only(top: 6), child: Text(time, style: AppTextStyles.caption.copyWith(fontSize: 9))),
                        ...List.generate(6, (dayIndex) {
                          DateTime cellDate = _currentWeekStart.add(Duration(days: dayIndex));
                          String key = "${cellDate.year}-${cellDate.month}-${cellDate.day}-$time";
                          List<AppointmentModel> slotAppts = appointmentsMap[key] ?? [];
                          return _buildCell(context, cellDate, time, slotAppts, _rowHeight);
                        }),
                      ])),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Nome do paciente na célula: até 2 linhas; se nem assim couber,
  /// reduz proporcionalmente (nunca estoura a célula/linha de 32px).
  Widget _buildCellLabel(
      IconData? icon, Color mainColor, String name, double maxWidth) {
    final w = maxWidth > 24 ? maxWidth - 8 : maxWidth;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: w,
        child: RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
              style: const TextStyle(fontSize: 12, fontFamily: 'Roboto'),
              children: [
                if (icon != null)
                  WidgetSpan(child: Icon(icon, size: 12, color: mainColor)),
                TextSpan(
                    text: " $name",
                    // Negrito adaptativo: branco no escuro, escuro no claro.
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ]),
        ),
      ),
    );
  }

  // --- LÓGICA DE VISUALIZAÇÃO DA CÉLULA (COM ORDENAÇÃO E DIVISÃO) ---
  Widget _buildCell(BuildContext context, DateTime date, String time, List<AppointmentModel> slotAppts, double rowHeight) {
    
    // 1. Filtra agendamentos ativos (não cancelados)
    List<AppointmentModel> activeAppts = slotAppts.where((a) => a.status != 'Cancelado').toList();
    
    // 2. ORDENAÇÃO: Garante que o primeiro agendado fique à esquerda.
    // O ideal é usar um campo 'createdAt'. Na falta dele, usamos 'id' para manter a ordem estável.
    activeAppts.sort((a, b) => a.id.compareTo(b.id)); 
    
    // 3. Busca cancelados apenas para exibir se não houver nada ativo
    AppointmentModel? cancelledAppt;
    if (activeAppts.isEmpty) {
      try { cancelledAppt = slotAppts.firstWhere((a) => a.status == 'Cancelado'); } catch (e) { cancelledAppt = null; }
    }

    int activeCount = activeAppts.length;

    // --- CENÁRIO A: Agendamentos Ativos (1 ou mais) ---
    if (activeAppts.isNotEmpty) {
      // O SizedBox com altura fixa é OBRIGATÓRIO para evitar o erro de layout "Infinite height"
      return SizedBox(
        height: rowHeight, 
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: activeAppts.map((appt) {
            
            bool isBlocked = appt.status == 'Bloqueado'; 
            bool isConfirmed = appt.status == 'Confirmado';
            bool isFinished = appt.status == 'Finalizado';
            bool isRemarcar = appt.status.toLowerCase() == 'remarcar' &&
                appt.proposedDate != null;
            
            Color mainColor;
            IconData? icon;

            if (isBlocked) {
              mainColor = Colors.grey;
              icon = Icons.lock;
            } else if (isFinished) {
              mainColor = Colors.grey; 
              icon = Icons.lock_clock;
            } else if (isRemarcar) {
              mainColor = Colors.orange;
              icon = Icons.event_repeat;
            } else if (isConfirmed) {
              mainColor = Colors.green;
              icon = Icons.check_circle;
            } else {
              mainColor = AppColors.primary;
            }

            final bgColor = isBlocked
                ? (AppColors.isDark
                    ? Colors.grey.withValues(alpha: 0.35)
                    : Colors.grey[300])
                : mainColor.withValues(alpha: 0.10);

            // Verifica se é o bloco inicial do horário para exibir o nome
            String startKey = "${appt.date.year}-${appt.date.month}-${appt.date.day}-${appt.date.hour.toString().padLeft(2, '0')}:${appt.date.minute.toString().padLeft(2, '0')}";
            String currentKey = "${date.year}-${date.month}-${date.day}-$time";
            bool isStart = (startKey == currentKey);

            // Expanded divide o espaço igualmente (2 eventos = 50% cada)
            return Expanded(
              child: LayoutBuilder(
                builder: (ctx, c) => InkWell(
                onTap: () => _showAppointmentOptions(appt, activeCount),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1), 
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: isStart ? const BorderRadius.vertical(top: Radius.circular(4)) : null,
                    border: Border(left: BorderSide(color: mainColor, width: 3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.centerLeft,
                  child: isStart
                      ? _buildCellLabel(icon, mainColor, appt.patientName, c.maxWidth)
                      : null,
                ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    } 
    // --- CENÁRIO B: Apenas Cancelado ---
    else if (cancelledAppt != null) {
       String startKey = "${cancelledAppt.date.year}-${cancelledAppt.date.month}-${cancelledAppt.date.day}-${cancelledAppt.date.hour.toString().padLeft(2, '0')}:${cancelledAppt.date.minute.toString().padLeft(2, '0')}";
       String currentKey = "${date.year}-${date.month}-${date.day}-$time";
       bool isStart = (startKey == currentKey);

       return InkWell(
        onTap: () {
           showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
             return SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   ListTile(
                     leading: const Icon(Icons.info_outline, color: Colors.orange),
                     title: Text("Cancelado: ${cancelledAppt!.patientName}"),
                     subtitle: const Text("Ver detalhes do cancelamento"),
                     onTap: () {
                       Navigator.pop(ctx);
                       _showCancellationDetails(cancelledAppt!);
                     }
                   ),
                   ListTile(
                     leading: const Icon(Icons.add, color: Colors.blue),
                     title: const Text("Novo Agendamento Aqui"),
                     onTap: () {
                       Navigator.pop(ctx);
                        Map<String, dynamic> preFill = {
                          'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day, int.parse(time.split(':')[0]), int.parse(time.split(':')[1]))),
                          'dentistId': _selectedDentistId 
                        };
                        Navigator.push(context, MaterialPageRoute(builder: (c) => AgendaFormScreen(initialData: preFill)));
                     }
                   )
                 ],
               ),
             );
           });
        },
        child: Container(
          height: rowHeight,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.centerLeft,
          child: isStart
              ? LayoutBuilder(
                  builder: (ctx, c) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: c.maxWidth > 8 ? c.maxWidth - 4 : c.maxWidth,
                      child: Text(
                        cancelledAppt!.patientName,
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                            decoration: TextDecoration.lineThrough),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      );
    }
    // --- CENÁRIO C: Vazio ---
    else {
      return InkWell(
        onTap: () {
          AgendaCellFactory.openForm(
            context: context,
            date: date,
            time: time,
            selectedDentistId: _selectedDentistId,
            fullWeekdayName: _getFullWeekDayName,
          );
        },
        child: SizedBox(height: rowHeight),
      );
    }
  }

  static const _shortWeekdays = ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"];
  static const _fullWeekdays = [
    "Segunda",
    "Terça",
    "Quarta",
    "Quinta",
    "Sexta",
    "Sábado",
    "Domingo"
  ];

  String _getWeekDayName(int weekday) => _shortWeekdays[weekday - 1];

  String _getFullWeekDayName(int weekday) => _fullWeekdays[weekday - 1];
}