import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:odonto_controle/models/financial_model.dart';
import 'package:odonto_controle/screens/patients/tabs/patient_financial_tab.dart';
import 'package:odonto_controle/services/financial_service.dart';
import 'package:odonto_controle/services/patient_service.dart';
import '../../ui/app_theme.dart';

import '../../widgets/patient_smart_context_card.dart'; 

import 'tabs/patient_details_tab.dart';
import 'tabs/budgets_tab.dart';
import 'tabs/treatments_tab.dart';
import 'tabs/odontogram_screen.dart'; 
import 'tabs/clinical_record_screen.dart'; 
import 'tabs/anamnesis_tab.dart';
import 'tabs/patient_lab_tab.dart'; 
// --- NOVO IMPORT ---
import 'tabs/patient_docs_tab.dart'; 
import '../../../services/clinic_capabilities.dart';
import '../../../services/session_manager.dart';
import 'package:odonto_controle/utils/display.dart';

class PatientDetailsScreen extends StatefulWidget {
  final String patientName; 
  final String patientId;
  final String? phone;
  final String? birth;
  final String? cpf;

  const PatientDetailsScreen({
    super.key,
    this.patientName = "Paciente", 
    required this.patientId,
    this.phone,
    this.birth,
    this.cpf,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  
  Widget _buildVisualTab() {
    final caps = ClinicCapabilities.current();
    if (caps.canShowOdontogram) {
      return OdontogramScreen(patientId: widget.patientId);
    }
    return const Center(
        child: Text("Módulo Visual não disponível para esta especialidade."));
  }

  @override
  Widget build(BuildContext context) {
    final caps = ClinicCapabilities.current();

    // Calcula número de tabs dinamicamente
    // Dental: 9 tabs | Psychology: 6 tabs (sem Orçamentos, Odontograma, Laboratório)
    // Outros: 9 tabs (desconhecido cai em dental)
    final int tabCount = caps.patientTabCount;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(widget.patientName, style: AppTextStyles.h2),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabs: [
              const Tab(text: "CADASTRO"),
              const Tab(text: "ANAMNESE"),
              if (caps.canShowBudgets) const Tab(text: "ORÇAMENTOS"),
              const Tab(text: "TRATAMENTOS"),
              const Tab(text: "PRONTUÁRIO"),
              if (caps.canShowOdontogram) const Tab(text: "ODONTOGRAMA"),
              if (caps.canShowLab) const Tab(text: "LABORATÓRIO"),
              const Tab(text: "DOCUMENTAÇÃO"),
              const Tab(text: "PAGAMENTOS"),
            ],
          ),
        ),
        body: Column(
          children: [
            _HeaderSummaryRow(patientId: widget.patientId),
            
            PatientSmartContextCard(patientId: widget.patientId),

            const SizedBox(height: 8),
            const Divider(height: 1),
            
            Expanded(
              child: TabBarView(
                children: [
                  PatientDetailsTab(patientName: widget.patientName, patientId: widget.patientId),
                  AnamnesisTab(patientId: widget.patientId),
                  if (caps.canShowBudgets)
                    BudgetsTab(patientName: widget.patientName, patientId: widget.patientId),
                  TreatmentsTab(patientName: widget.patientName, patientId: widget.patientId),
                  ClinicalRecordTab(patientName: widget.patientName, patientId: widget.patientId),
                  if (caps.canShowOdontogram) _buildVisualTab(),
                  if (caps.canShowLab) PatientLabTab(patientId: widget.patientId),
                  PatientDocsTab(patientId: widget.patientId),
                  PatientFinancialTab(patientId: widget.patientId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET DE CABEÇALHO (MANTIDO IGUAL AO SEU ORIGINAL) ---
class _HeaderSummaryRow extends StatelessWidget {
  final String patientId;
  const _HeaderSummaryRow({required this.patientId});

  @override
  Widget build(BuildContext context) {
    final FinancialService finService = FinancialService();
    final PatientService patientService = PatientService(); 

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: patientService.getPatientRiskProfile(patientId), 
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _buildLoadingCard();
                
                final data = snapshot.data!;
                final level = data['level'];
                
                Color color;
                String label;
                String valueText;

                if (level == 'red') {
                  color = Colors.red;
                  label = "RISCO ALTO";
                  valueText = "Faltante";
                } else if (level == 'yellow') {
                  color = Colors.orange;
                  label = "ATENÇÃO";
                  valueText = "Irregular";
                } else {
                  color = Colors.green;
                  label = "ASSIDUIDADE";
                  valueText = "Excelente";
                }

                return _buildSummaryItem(label, valueText, color, isTextValue: true);
              },
            ),
          ),
          
          const SizedBox(width: 8),

          Expanded(
            flex: 1,
            child: StreamBuilder<List<FinancialModel>>(
              stream: finService.getByPatientId(patientId),
              builder: (context, snapshot) {
                double pendente = 0;
                if (snapshot.hasData) {
                  for (var item in snapshot.data!) {
                    if (item.status.toLowerCase() == 'cancelado') continue;
                    if (!item.isPaid) {
                      pendente += item.amount - item.paidAmount;
                    }
                  }
                }
                return _buildSummaryItem("A RECEBER", "${formatBRL(pendente)}", Colors.orange);
              },
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            flex: 1,
            child: StreamBuilder<List<FinancialModel>>(
              stream: finService.getByPatientId(patientId),
              builder: (context, snapshot) {
                double recebido = 0;
                if (snapshot.hasData) {
                  for (var item in snapshot.data!) {
                    if (item.isPaid) recebido += item.amount;
                  }
                }
                return _buildSummaryItem("RECEBIDO", "${formatBRL(recebido)}", Colors.green);
              },
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: SessionManager()
                  .applyFilter(FirebaseFirestore.instance
                      .collection('expenses')
                      .where('relatedPatientId', isEqualTo: patientId))
                  .snapshots(),
              builder: (context, snapshot) {
                double custo = 0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final raw = data['amount'];
                    custo += raw is num
                        ? raw.toDouble()
                        : double.tryParse('$raw') ?? 0.0;
                  }
                }
                return _buildSummaryItem("CUSTO OPERACIONAL",
                    "${formatBRL(custo)}", Colors.orange);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, {bool isTextValue = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold, 
              color: AppColors.textSecondary, 
              fontSize: 10 
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox( 
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value, 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: color
              )
            ),
          ),
        ],
      ),
    );
  }
}