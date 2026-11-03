import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/budget_service.dart';
import '../../../services/budget_delete_service.dart';
import '../../../services/procedure_service.dart';
import '../../../services/session_manager.dart';
import '../../../services/treatment_service.dart';
import '../../../models/budget_model.dart';
import '../../../utils/display.dart';
import '../../../utils/budget_print.dart';
import '../../../utils/external_link.dart';
import '../clinical_budgets_view.dart';
import '../budget_create_dialog.dart';
import '../wizards/budget_approval_wizard.dart';

class BudgetsTab extends StatefulWidget {
  const BudgetsTab({
    super.key,
    required this.patientName,
    required this.patientId,
    this.embedded = false,
    this.onTreatment,
  });
  final String patientName, patientId;
  final bool embedded;
  final ValueChanged<String>? onTreatment;
  @override
  State<BudgetsTab> createState() => _BudgetsTabState();
}

class _BudgetsTabState extends State<BudgetsTab> {
  final _budgetService = BudgetService();
  late Stream<List<BudgetModel>> _budgets;
  late Stream<QuerySnapshot> _plans;
  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant BudgetsTab old) {
    super.didUpdateWidget(old);
    if (old.patientId != widget.patientId) _init();
  }

  void _init() {
    _budgets = _budgetService.getByPatient(widget.patientId);
    _plans = TreatmentService().getPlansStream(widget.patientId);
  }

  Future<void> _showCreateBudgetDialog(BuildContext context) async {
    final clinic = SessionManager().currentClinicId;
    final patientId = widget.patientId;
    final patientName = widget.patientName;
    if (clinic == null) return;
    final ref = FirebaseFirestore.instance.collection('budgets').doc();
    final procedures = ProcedureService().getAllStream();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BudgetCreateDialog(
        patientName: patientName,
        clinicName: SessionManager().currentClinicName ?? 'Unidade selecionada',
        procedures: procedures,
        onSave: (items, total, metadata) async {
          if (!mounted ||
              widget.patientId != patientId ||
              SessionManager().currentClinicId != clinic) {
            throw StateError('Unidade alterada');
          }
          final details = <String, dynamic>{
            ...metadata,
            if (metadata['validUntil'] is DateTime)
              'validUntil': Timestamp.fromDate(
                metadata['validUntil'] as DateTime,
              ),
            'clinicName': SessionManager().currentClinicName ?? '',
          };
          final budget = BudgetModel(
            id: ref.id,
            clinicId: clinic,
            patientId: patientId,
            patientName: patientName,
            total: total,
            status: 'Pendente',
            date: DateTime.now(),
            items: items,
            details: details,
          );
          await ref.set(budget.toMap());
        },
      ),
    );
  }

  Future<void> _approveBudget(BuildContext context, BudgetModel b) async {
    if (b.clinicId != SessionManager().currentClinicId) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BudgetApprovalWizard(budget: b),
    );
  }

  Future<void> _print(List<BudgetModel> budgets) async {
    final clinic = SessionManager().currentClinicId;
    if (clinic == null || budgets.any((b) => b.clinicId != clinic)) return;
    final name = SessionManager().currentClinicName ?? 'Unidade selecionada';
    try {
      await printBudgetProposals(
        budgets,
        name,
        stillValid: () => mounted && SessionManager().currentClinicId == clinic,
      );
    } catch (e) {
      if (mounted) {
        toast(context, 'Não foi possível imprimir a proposta.', error: true);
      }
    }
  }

  // --- EXCLUSÃO (pendente: só o doc; aprovado: cadeia) ---
  bool _deletingBudget = false;

  void _confirmDeleteBudget(BudgetModel budget) {
    final approved =
        budgetGroup(budget, DateTime.now()) == BudgetGroup.approved;
    final Future<Map<String, int>> countsFuture = approved
        ? _readPlanId(budget.id).then<Map<String, int>>(
            (planId) => planId.isEmpty
                ? <String, int>{}
                : BudgetDeleteService().countChildren(budget.id, planId),
          )
        : Future.value(<String, int>{});

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Excluir orçamento?",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!approved)
                const Text(
                  "Orçamento ainda pendente: apaga somente o orçamento. Nada mais será tocado.",
                )
              else ...[
                const Text(
                  "Orçamento APROVADO: apaga em cadeia tratamentos, pagamentos, custos e parcelas. NÃO há reversão:",
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, int>>(
                  future: countsFuture,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snap.data!.isEmpty) {
                      return const Text(
                        "Nenhum vinculado encontrado (só o orçamento sai).",
                        style: TextStyle(fontSize: 13),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in snap.data!.entries)
                          if (e.value > 0)
                            Text(
                              "• ${e.key}: ${e.value}",
                              style: const TextStyle(fontSize: 13),
                            ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Voltar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runDeleteBudget(budget, approved);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(approved ? "EXCLUIR TUDO" : "EXCLUIR"),
          ),
        ],
      ),
    );
  }

  Future<String> _readPlanId(String budgetId) async {
    try {
      final d = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(budgetId)
          .get();
      return '${(d.data() ?? {})['relatedPlanId'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _runDeleteBudget(BudgetModel budget, bool approved) async {
    if (_deletingBudget ||
        budget.clinicId != SessionManager().currentClinicId ||
        budget.patientId != widget.patientId) {
      return;
    }
    setState(() => _deletingBudget = true);
    String stage = 'Iniciando...';
    var started = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          if (!started) {
            started = true;
            () async {
              try {
                await BudgetDeleteService().deleteBudget(
                  budgetId: budget.id,
                  patientId: widget.patientId,
                  approved: approved,
                  onStage: (s) {
                    stage = s;
                    if (ctx.mounted) setDlg(() {});
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  toast(context, "Orçamento excluído.", ok: true);
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  toast(context, "Falha ao excluir: $e", error: true);
                }
              } finally {
                if (mounted) {
                  setState(() => _deletingBudget = false);
                }
              }
            }();
          }
          return AlertDialog(
            title: const Text("Excluindo..."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(stage, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.patientId.isEmpty) {
      return const Center(child: Text('Paciente não informado.'));
    }
    final content = StreamBuilder<List<BudgetModel>>(
      stream: _budgets,
      builder: (context, snap) => StreamBuilder<QuerySnapshot>(
        stream: _plans,
        builder: (context, plans) {
          final data = <String, Map<String, dynamic>>{};
          if (plans.connectionState == ConnectionState.active &&
              plans.hasData &&
              !plans.hasError) {
            for (final d in plans.data!.docs) {
              data[d.id] = {'id': d.id, ...d.data() as Map<String, dynamic>};
            }
          }
          String planId(BudgetModel b) =>
              data.containsKey('${b.details['relatedPlanId'] ?? ''}')
              ? '${b.details['relatedPlanId']}'
              : '${data.values.where((p) => p['budgetId'] == b.id).firstOrNull?['id'] ?? ''}';
          return ClinicalBudgetsView(
            key: ValueKey('budgets-${widget.patientId}'),
            budgets: snap.data ?? [],
            plans: data,
            loading:
                snap.connectionState != ConnectionState.active &&
                !snap.hasError,
            error: snap.hasError
                ? 'Não foi possível carregar os orçamentos desta unidade.'
                : null,
            plansError: plans.hasError
                ? 'Não foi possível consultar os tratamentos vinculados.'
                : null,
            deleting: _deletingBudget,
            onNew: () => _showCreateBudgetDialog(context),
            onApprove: (b) => _approveBudget(context, b),
            onDelete: _confirmDeleteBudget,
            onPrint: (b) => _print([b]),
            onPrintAll: _print,
            onShare: (b) async {
              final url = budgetLink(
                b.details['shareUrl'] ?? b.details['proposalUrl'],
              );
              if (url == null) return;
              await Clipboard.setData(ClipboardData(text: url.toString()));
              if (context.mounted) {
                toast(context, 'Link da proposta copiado.', ok: true);
              }
            },
            onTreatment: (b) {
              final id = planId(b);
              if (id.isEmpty) return;
              if (widget.onTreatment != null) {
                widget.onTreatment!(id);
              } else {
                DefaultTabController.maybeOf(context)?.animateTo(3);
              }
            },
            onReceipt: (b) {
              final url = budgetLink(
                b.details['receiptUrl'] ?? data[planId(b)]?['receiptUrl'],
              );
              if (url != null) openLinkSafe(openBlankTab(), url.toString());
            },
          );
        },
      ),
    );
    return widget.embedded
        ? content
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: content,
          );
  }
}
