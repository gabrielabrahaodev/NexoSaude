import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/patient_model.dart';
import '../../models/financial_model.dart';
import '../../services/clinic_capabilities.dart';
import '../../services/session_manager.dart';
import '../../services/patient_service.dart';
import '../../services/financial_service.dart';
import '../../utils/display.dart';
import '../../widgets/patient_smart_context_card.dart';
import '../agenda/clinical_agenda_view.dart';
import '../dashboard/main_web_dashboard.dart';
import 'clinical_patient_view.dart';
import 'tabs/patient_details_tab.dart';
import 'tabs/anamnesis_tab.dart';
import 'tabs/budgets_tab.dart';
import 'tabs/treatments_tab.dart';
import 'tabs/clinical_record_screen.dart';
import 'tabs/odontogram_screen.dart';
import 'tabs/patient_lab_tab.dart';
import 'tabs/patient_docs_tab.dart';
import 'tabs/patient_financial_tab.dart';

class ClinicalPatientScreen extends StatefulWidget {
  const ClinicalPatientScreen({
    super.key,
    required this.patientId,
    required this.fallbackName,
    this.initialTab,
  });
  final String patientId, fallbackName;
  final int? initialTab;
  @override
  State<ClinicalPatientScreen> createState() => _ClinicalPatientScreenState();
}

class _ClinicalPatientScreenState extends State<ClinicalPatientScreen> {
  late final String? _clinicId;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _patient;
  late final Stream<List<FinancialModel>> _financial;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _expenses;
  late final Future<Map<String, dynamic>> _risk;
  late int _index;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _clinicId = SessionManager().currentClinicId;
    final db = FirebaseFirestore.instance;
    _patient = SessionManager()
        .applyFilter(
          db
              .collection('patients')
              .where(FieldPath.documentId, isEqualTo: widget.patientId),
        )
        .snapshots();
    _financial = FinancialService().getByPatientId(widget.patientId);
    _expenses = SessionManager()
        .applyFilter(
          db
              .collection('expenses')
              .where('relatedPatientId', isEqualTo: widget.patientId),
        )
        .snapshots();
    _risk = PatientService().getPatientRiskProfile(widget.patientId);
    _index =
        widget.initialTab ??
        (ClinicCapabilities.current().canShowOdontogram ? 5 : 0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int value) {
    setState(() => _index = value);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final caps = ClinicCapabilities.current();
    final entries = <({String name, IconData icon})>[
      (name: 'Cadastro', icon: Icons.person_outline),
      (name: 'Anamnese', icon: Icons.assignment_outlined),
      if (caps.canShowBudgets)
        (name: 'Orçamentos', icon: Icons.request_quote_outlined),
      (name: 'Tratamentos', icon: Icons.handyman_outlined),
      (name: 'Prontuário', icon: Icons.assignment_ind_outlined),
      if (caps.canShowOdontogram)
        (name: 'Odontograma', icon: Icons.grid_on_outlined),
      if (caps.canShowLab) (name: 'Laboratório', icon: Icons.science_outlined),
      (name: 'Documentação', icon: Icons.folder_outlined),
      (name: 'Pagamentos', icon: Icons.payments_outlined),
    ];
    final index = _index.clamp(0, entries.length - 1);
    final selected = entries[index].name;
    final content = Theme(
      data: PatientVisualStyle.theme,
      child: Scaffold(
        backgroundColor: PatientVisualStyle.background,
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _patient,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Não foi possível carregar o paciente. Verifique a conexão e o acesso à unidade.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('Paciente não encontrado nesta unidade.'),
              );
            }
            final doc = snapshot.data!.docs.first;
            final data = doc.data();
            final patient = PatientModel.fromMap(doc.id, data);
            Widget legacy(Widget child) => SizedBox(
              height: MediaQuery.sizeOf(
                context,
              ).height.clamp(560, 1000).toDouble(),
              child: child,
            );
            final treatment = TreatmentsTab(
              patientName: patient.name,
              patientId: patient.id,
              embedded: true,
              onPayments: () => _select(entries.length - 1),
            );
            final financial = PatientFinancialTab(
              patientId: patient.id,
              embedded: true,
            );
            final panels = <Widget>[
              switch (selected) {
                'Cadastro' => legacy(
                  PatientDetailsTab(
                    patientName: patient.name,
                    patientId: patient.id,
                  ),
                ),
                'Anamnese' => legacy(AnamnesisTab(patientId: patient.id)),
                'Orçamentos' => legacy(
                  BudgetsTab(patientName: patient.name, patientId: patient.id),
                ),
                'Tratamentos' => treatment,
                'Prontuário' => legacy(
                  ClinicalRecordTab(
                    patientName: patient.name,
                    patientId: patient.id,
                  ),
                ),
                'Odontograma' => OdontogramScreen(
                  patientId: patient.id,
                  embedded: true,
                ),
                'Laboratório' => legacy(PatientLabTab(patientId: patient.id)),
                'Documentação' => legacy(PatientDocsTab(patientId: patient.id)),
                _ => financial,
              },
              if (selected == 'Odontograma') ...[
                PatientSectionHeading(
                  title: 'Planos de tratamento em execução',
                  subtitle:
                      'Acompanhamento clínico, rentabilidade e liquidação financeira',
                  action: OutlinedButton.icon(
                    onPressed: () => _select(2),
                    style: OutlinedButton.styleFrom(backgroundColor: ClinicalAgendaStyle.blue, foregroundColor: const Color(0xFF002E6A)),
                    icon: const Icon(Icons.add_circle_outline, size: 17),
                    label: const Text('Novo tratamento'),
                  ),
                ),
                treatment,
                financial,
              ],
            ];
            return LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                  c.maxWidth < 600 ? 12 : 24,
                  0,
                  c.maxWidth < 600 ? 12 : 24,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClinicalPatientHeader(
                      name: patient.name,
                      id: patient.id,
                      status: patient.status,
                      consent:
                          (data['lgpdPortalConsent'] is Map) &&
                          (data['lgpdPortalConsent'] as Map)['accepted'] ==
                              true,
                      psychology: caps.isPsychology,
                      birth: patient.birthDate,
                      cpf: patient.cpf,
                      phone: patient.phone,
                      onBack: () => Navigator.maybePop(context),
                      onPayments: () => _select(entries.length - 1),
                      onRegistration: () => _select(0),
                    ),
                    const SizedBox(height: 16),
                    PatientVisualStyle.panel(
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < entries.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TextButton.icon(
                                  onPressed: () => _select(i),
                                  style: TextButton.styleFrom(
                                    backgroundColor: i == index
                                        ? ClinicalAgendaStyle.teal
                                        : Colors.transparent,
                                    foregroundColor: i == index
                                        ? const Color(0xFF00382C)
                                        : ClinicalAgendaStyle.text,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: Icon(entries[i].icon, size: 17),
                                  label: Text(
                                    entries[i].name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      padding: 6,
                    ),
                    const SizedBox(height: 16),
                    _metrics(),
                    const SizedBox(height: 16),
                    PatientSmartContextCard(
                      key: ValueKey('context-${patient.id}'),
                      patientId: patient.id,
                      clinical: true,
                    ),
                    const SizedBox(height: 16),
                    ...panels,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    return MainWebDashboard(
      detail: content,
      detailClinicId: _clinicId,
      initialIndex: 2,
    );
  }

  Widget _metrics() => StreamBuilder<List<FinancialModel>>(
    stream: _financial,
    builder: (context, snapshot) =>
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _expenses,
          builder: (context, expenses) {
            final charges = (snapshot.data ?? <FinancialModel>[])
                .where(
                  (f) =>
                      f.status.toLowerCase() != 'cancelado' &&
                      !FinancialModel.isReplaced(f.status),
                )
                .toList();
            final pending = charges
                .where((f) => !f.isPaid)
                .fold<double>(
                  0,
                  (v, f) =>
                      v + (f.amount - f.paidAmount).clamp(0, double.infinity),
                );
            final received = charges
                .where((f) => f.isPaid)
                .fold<double>(0, (v, f) => v + f.amount);
            final total = charges.fold<double>(0, (v, f) => v + f.amount);
            final cost =
                expenses.data?.docs.fold<double>(
                  0,
                  (v, d) => v + parseBRL(d.data()['amount']),
                ) ??
                0;
            final overdue = charges
                .where(
                  (f) =>
                      !f.isPaid &&
                      f.dueDate != null &&
                      f.dueDate!.isBefore(DateTime.now()),
                )
                .length;
            final waiting = snapshot.hasError
                ? 'Indisponível'
                : (!snapshot.hasData ? 'Carregando…' : null);
            return ClinicalPatientMetrics(
              items: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _risk,
                  builder: (context, r) {
                    final level = r.data?['level'];
                    return PatientMetric(
                      label: 'ASSIDUIDADE',
                      value: !r.hasData
                          ? 'Carregando…'
                          : (level == 'red'
                                ? 'Faltante'
                                : level == 'yellow'
                                ? 'Irregular'
                                : 'Excelente'),
                      detail: r.hasData
                          ? '${r.data?['missed'] ?? 0} faltas nos últimos agendamentos'
                          : 'Consultando histórico',
                      icon: Icons.event_available,
                      color: level == 'red'
                          ? const Color(0xFFFFB4AB)
                          : level == 'yellow'
                          ? PatientVisualStyle.warning
                          : PatientVisualStyle.accent,
                      progress: r.hasData ? 1 : 0,
                    );
                  },
                ),
                PatientMetric(
                  label: 'A RECEBER',
                  value: waiting ?? formatBRL(pending),
                  detail:
                      waiting ??
                      (overdue > 0
                          ? '$overdue pendência(s) vencida(s)'
                          : 'Sem pendências vencidas'),
                  icon: Icons.pending_actions,
                  color: PatientVisualStyle.warning,
                  progress: total > 0 ? pending / total : 0,
                ),
                PatientMetric(
                  label: 'RECEBIDO',
                  value: waiting ?? formatBRL(received),
                  detail: waiting ?? 'Pagamentos liquidados',
                  icon: Icons.check_circle_outline,
                  color: PatientVisualStyle.accent,
                  progress: total > 0 ? received / total : 0,
                ),
                PatientMetric(
                  label: 'CUSTO OPERACIONAL',
                  value: expenses.hasError
                      ? 'Indisponível'
                      : (!expenses.hasData ? 'Carregando…' : formatBRL(cost)),
                  detail: expenses.hasError
                      ? 'Falha ao carregar custos'
                      : 'Custos vinculados ao paciente',
                  icon: Icons.pie_chart_outline,
                  color: ClinicalAgendaStyle.blue,
                  progress: expenses.hasData ? 1 : 0,
                ),
              ],
            );
          },
        ),
  );
}
