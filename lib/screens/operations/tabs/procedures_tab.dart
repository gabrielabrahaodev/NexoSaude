import 'package:flutter/material.dart';
import '../../../models/procedure_model.dart';
import '../../../services/procedure_service.dart';
import '../../../services/session_manager.dart';
import '../../../ui/app_theme.dart';
import '../../../utils/display.dart';
import '../clinical_procedures_view.dart';

class ProceduresTab extends StatefulWidget {
  const ProceduresTab({super.key});
  @override
  State<ProceduresTab> createState() => _ProceduresTabState();
}

class _ProceduresTabState extends State<ProceduresTab> {
  final ProcedureService _service = ProcedureService();

  late final _catalog = _service.getAllStream();

  Future<void> _showEditDialog({ProcedureModel? model}) async {
    final openedClinicId = SessionManager().currentClinicId;
    bool saving = false;
    String? error;
    final nameCtrl = TextEditingController(text: model?.name);
    final priceCtrl = TextEditingController(text: model?.price.toStringAsFixed(2));
    final categoryCtrl = TextEditingController(text: model?.category ?? 'Geral');
    
    // Controlador da Comissão
    final commissionValueCtrl = TextEditingController(
      text: model?.commissionValue.toStringAsFixed(model.commissionType == 'percent' ? 1 : 2) ?? '0.0'
    );
    
    // Variáveis de estado locais
    bool hasCost = model?.hasCost ?? false;
    bool generatesMonthlyFee = model?.generatesMonthlyFee ?? false;
    String commissionType = model?.commissionType ?? 'percent'; // 'percent' ou 'fixed'

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(model == null ? "Novo Procedimento" : "Editar Procedimento"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome")),
                    const SizedBox(height: 10),
                    TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: "Categoria (Ex: Cirurgia)")),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceCtrl, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Preço Sugerido (R\$)", prefixText: "R\$ ")
                    ),
                    const SizedBox(height: 20),
                    
                    // --- SEÇÃO DE COMISSÃO / REPASSE ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Repasse Profissional (Comissão)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: commissionType,
                            isExpanded: true,
                            items: const [DropdownMenuItem(value: 'percent', child: Text('Porcentagem (%)')), DropdownMenuItem(value: 'fixed', child: Text('Valor fixo (R\$)'))],
                            onChanged: saving ? null : (v) => setStateModal(() => commissionType = v!),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: commissionValueCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: commissionType == 'percent' ? "Porcentagem do Repasse" : "Valor do Repasse",
                              suffixText: commissionType == 'percent' ? "%" : null,
                              prefixText: commissionType == 'fixed' ? "R\$ " : null,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Divider(),
                    
                    // --- FLAGS ---
                    SwitchListTile(
                      title: const Text("Gera Custos/Despesas?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Ex: Laboratório, Protético", style: TextStyle(fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                      value: hasCost,
                      activeColor: Colors.orange,
                      onChanged: (val) => setStateModal(() => hasCost = val),
                    ),
                    
                    SwitchListTile(
                      title: const Text("Gera Mensalidade?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Ex: Manutenção Ortodôntica (12x)", style: TextStyle(fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                      value: generatesMonthlyFee,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setStateModal(() => generatesMonthlyFee = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    final clinicId = SessionManager().currentClinicId;
                    if (clinicId == null || clinicId != openedClinicId) {
                      setStateModal(() => error = 'A unidade mudou. Feche e reabra o formulário.'); return;
                    }
                    final price = parseBRL(priceCtrl.text);
                    final commission = parseBRL(commissionValueCtrl.text);
                    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty || !price.isFinite || price < 0 || !commission.isFinite || commission < 0 || (commissionType == 'percent' && commission > 100)) {
                      setStateModal(() => error = 'Informe nome, preço válido e repasse entre 0 e 100% ou um valor fixo positivo.'); return;
                    }
                    setStateModal(() { saving = true; error = null; });

                    final newModel = ProcedureModel(
                      id: model?.id ?? '', 
                      clinicId: clinicId,
                      name: nameCtrl.text.trim(),
                      category: categoryCtrl.text,
                      price: price,
                      active: model?.active ?? true,
                      hasCost: hasCost,
                      generatesMonthlyFee: generatesMonthlyFee,
                      // Novos Campos
                      commissionType: commissionType,
                      commissionValue: commission,
                    );
                    
                    try {
                      await _service.save(newModel);
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) setStateModal(() { saving = false; error = 'Não foi possível salvar. Seus dados foram mantidos.'; });
                    }
                  },
                  child: const Text("Salvar"),
                )
              ],
            );
          }
        );
      },
    );
    nameCtrl.dispose(); priceCtrl.dispose(); categoryCtrl.dispose(); commissionValueCtrl.dispose();
  }

  Future<void> _confirmDelete(ProcedureModel item) async {
    final clinic = SessionManager().currentClinicId;
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Excluir procedimento?'), content: Text('Excluir "${item.name}" do catálogo? Os registros clínicos existentes não serão alterados.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir'))],
    ));
    if (confirmed != true || !mounted || clinic != SessionManager().currentClinicId) return;
    try { await _service.delete(item.id); }
    catch (_) { if (mounted) toast(context, 'Não foi possível excluir o procedimento.', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProcedureModel>>(
      stream: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Não foi possível carregar os procedimentos. Reabra a tela para tentar novamente.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ClinicalProceduresView(items: snapshot.data!, onNew: () => _showEditDialog(), onEdit: (item) => _showEditDialog(model: item), onDelete: _confirmDelete);
      },
    );
  }
}
