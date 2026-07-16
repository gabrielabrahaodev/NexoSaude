import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/session_manager.dart';

// Classe auxiliar para as linhas de regras
class InstallmentRangeRow {
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final TextEditingController rateCtrl;

  InstallmentRangeRow({int? from, int? to, double? rate})
      : fromCtrl = TextEditingController(text: from?.toString() ?? ''),
        toCtrl = TextEditingController(text: to?.toString() ?? ''),
        rateCtrl = TextEditingController(text: rate?.toString() ?? '');
}

// Modelo simples para o Dropdown
class MachineProfile {
  final String id;
  final String name;
  MachineProfile({required this.id, required this.name});
}

class CardFeesTab extends StatefulWidget {
  const CardFeesTab({super.key});

  @override
  State<CardFeesTab> createState() => _CardFeesTabState();
}

class _CardFeesTabState extends State<CardFeesTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // --- GERENCIAMENTO DE PERFIS ---
  List<MachineProfile> _profiles = [];
  String? _selectedProfileId; // ID do perfil sendo editado agora
  String? _activeProfileId;   // ID do perfil que é o PADRÃO da clínica

  // --- CAMPOS DO FORMULÁRIO ---
  final _machineNameCtrl = TextEditingController();
  final _debitCtrl = TextEditingController();
  final _credit1xCtrl = TextEditingController();
  
  // Antecipação
  bool _anticipationEnabled = false;
  final _anticipationRateCtrl = TextEditingController();

  // Regras Dinâmicas
  List<InstallmentRangeRow> _installmentRanges = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // --- LÓGICA DE CARREGAMENTO ---

  Future<void> _loadAllData() async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Busca qual é o perfil ativo (Padrão)
      final docSettings = await FirebaseFirestore.instance
          .collection('clinics').doc(clinicId)
          .collection('settings').doc('fees')
          .get();
      
      if (docSettings.exists) {
        _activeProfileId = docSettings.data()?['activeProfileId'];
      }

      // 2. Busca a lista de perfis salvos na subcoleção
      final snapshot = await FirebaseFirestore.instance
          .collection('clinics').doc(clinicId)
          .collection('settings').doc('fees')
          .collection('profiles')
          .get();

      _profiles = snapshot.docs.map((d) => MachineProfile(
        id: d.id, 
        name: d.data()['machine_name'] ?? 'Sem Nome'
      )).toList();

      // 3. Decide qual exibir: O selecionado, ou o Ativo, ou o Primeiro, ou Novo
      if (_selectedProfileId == null) {
        if (_activeProfileId != null && _profiles.any((p) => p.id == _activeProfileId)) {
          _selectedProfileId = _activeProfileId;
        } else if (_profiles.isNotEmpty) {
          _selectedProfileId = _profiles.first.id;
        } else {
          _selectedProfileId = null; // Modo "Nova Máquina"
        }
      }

      // 4. Carrega os dados do perfil selecionado
      await _loadSelectedProfileData();

    } catch (e) {
      debugPrint("Erro load: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSelectedProfileData() async {
    _clearForm(); // Limpa antes de carregar

    if (_selectedProfileId == null) return; // É um perfil novo, deixa limpo

    final clinicId = SessionManager().currentClinicId;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clinics').doc(clinicId)
          .collection('settings').doc('fees')
          .collection('profiles').doc(_selectedProfileId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _machineNameCtrl.text = data['machine_name'] ?? '';
        _debitCtrl.text = (data['debit'] ?? 0.0).toString();
        _credit1xCtrl.text = (data['credit_1x'] ?? 0.0).toString();
        _anticipationEnabled = data['anticipation_enabled'] ?? false;
        _anticipationRateCtrl.text = (data['anticipation_rate'] ?? 0.0).toString();

        if (data['installment_rules'] != null) {
          final rules = data['installment_rules'] as List<dynamic>;
          for (var r in rules) {
            _installmentRanges.add(InstallmentRangeRow(
              from: r['from'], to: r['to'], rate: (r['rate'] ?? 0.0).toDouble(),
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao ler perfil: $e");
    }
    
    if (_installmentRanges.isEmpty) _addRange();
  }

  void _clearForm() {
    _machineNameCtrl.clear();
    _debitCtrl.clear();
    _credit1xCtrl.clear();
    _anticipationEnabled = false;
    _anticipationRateCtrl.clear();
    _installmentRanges.clear();
  }

  // --- LÓGICA DE AÇÕES ---

  void _createNewProfile() {
    setState(() {
      _selectedProfileId = null; // Null indica novo
      _clearForm();
      _addRange();
    });
  }

  void _addRange() {
    setState(() => _installmentRanges.add(InstallmentRangeRow()));
  }

  void _removeRange(int index) {
    setState(() => _installmentRanges.removeAt(index));
  }

  Future<void> _deleteProfile() async {
    if (_selectedProfileId == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Máquina"),
        content: const Text("Tem certeza? Isso não pode ser desfeito."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Excluir")),
        ],
      )
    );

    if (confirm != true) return;

    final clinicId = SessionManager().currentClinicId;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('clinics').doc(clinicId)
          .collection('settings').doc('fees')
          .collection('profiles').doc(_selectedProfileId)
          .delete();
      
      // Se era o ativo, remove a referência
      if (_activeProfileId == _selectedProfileId) {
         await FirebaseFirestore.instance
          .collection('clinics').doc(clinicId)
          .collection('settings').doc('fees')
          .update({'activeProfileId': null});
         _activeProfileId = null;
      }

      _selectedProfileId = null; // Volta para modo novo
      await _loadAllData(); // Recarrega lista
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perfil excluído.")));

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao excluir."), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveFees() async {
    if (!_formKey.currentState!.validate()) return;
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;

    if (_machineNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dê um nome para a máquina (ex: Stone)."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    try {
      double p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
      int i(TextEditingController c) => int.tryParse(c.text) ?? 0;

      List<Map<String, dynamic>> rulesList = [];
      for (var row in _installmentRanges) {
        if (row.fromCtrl.text.isNotEmpty && row.toCtrl.text.isNotEmpty) {
          rulesList.add({
            'from': i(row.fromCtrl),
            'to': i(row.toCtrl),
            'rate': p(row.rateCtrl),
          });
        }
      }
      rulesList.sort((a, b) => (a['from'] as int).compareTo(b['from'] as int));

      // Referência da coleção de perfis
      final profilesRef = FirebaseFirestore.instance
          .collection('clinics').doc(clinicId)
          .collection('settings').doc('fees')
          .collection('profiles');

      DocumentReference docRef;
      if (_selectedProfileId == null) {
        docRef = profilesRef.doc(); // Cria novo ID
      } else {
        docRef = profilesRef.doc(_selectedProfileId); // Usa existente
      }

      await docRef.set({
        'machine_name': _machineNameCtrl.text.trim(),
        'debit': p(_debitCtrl),
        'credit_1x': p(_credit1xCtrl),
        'anticipation_enabled': _anticipationEnabled,
        'anticipation_rate': p(_anticipationRateCtrl),
        'installment_rules': rulesList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Se for o primeiro ou o usuário marcou para ser o padrão (lógica simples: sempre torna o último salvo o padrão ou mantém)
      // Vamos tornar o padrão se não houver nenhum
      if (_activeProfileId == null) {
        _activeProfileId = docRef.id;
        await FirebaseFirestore.instance
            .collection('clinics').doc(clinicId)
            .collection('settings').doc('fees')
            .set({'activeProfileId': docRef.id}, SetOptions(merge: true));
      }

      _selectedProfileId = docRef.id;
      await _loadAllData(); // Atualiza dropdown

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salvo com sucesso!")));
    } catch (e) {
      print(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makeActive() async {
    if (_selectedProfileId == null) return;
    final clinicId = SessionManager().currentClinicId;
    
    await FirebaseFirestore.instance
        .collection('clinics').doc(clinicId)
        .collection('settings').doc('fees')
        .set({'activeProfileId': _selectedProfileId}, SetOptions(merge: true));
    
    setState(() {
      _activeProfileId = _selectedProfileId;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Esta máquina agora é a PADRÃO para cálculos.")));
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profiles.isEmpty) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileSelector(),
              const SizedBox(height: 16),
              if (_selectedProfileId != null && _selectedProfileId == _activeProfileId)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 8), Text("Esta é a máquina padrão utilizada nos cálculos.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                ),

              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildDebitAndCredit1xCard(),
              const SizedBox(height: 16),
              _buildInstallmentRulesCard(),
              const SizedBox(height: 16),
              _buildAnticipationCard(),
              const SizedBox(height: 30),
              
              Row(
                children: [
                  if (_selectedProfileId != null && _selectedProfileId != _activeProfileId)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _makeActive,
                        child: const Text("Definir como Padrão"),
                      ),
                    ),
                  if (_selectedProfileId != null && _selectedProfileId != _activeProfileId)
                    const SizedBox(width: 10),
                    
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveFees,
                        icon: const Icon(Icons.save),
                        label: const Text("SALVAR PERFIL"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.settings_remote, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProfileId,
                  hint: const Text("Nova Máquina..."),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text("+ Nova Máquina / Perfil", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                    ..._profiles.map((p) => DropdownMenuItem(
                      value: p.id, 
                      child: Row(children: [
                        Text(p.name),
                        if (p.id == _activeProfileId) ...[const SizedBox(width: 5), const Icon(Icons.star, size: 14, color: Colors.amber)]
                      ]),
                    )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedProfileId = val;
                    });
                    _loadSelectedProfileData();
                  },
                ),
              ),
            ),
            if (_selectedProfileId != null)
              IconButton(onPressed: _deleteProfile, icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: "Excluir Perfil")
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _machineNameCtrl,
          decoration: const InputDecoration(
            labelText: "Nome da Máquina / Perfil",
            hintText: "Ex: Stone Principal...",
            border: OutlineInputBorder(),
          ),
          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
        ),
      ),
    );
  }

  Widget _buildDebitAndCredit1xCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _buildInputBox("Débito (%)", _debitCtrl, Colors.blue)),
            const SizedBox(width: 15),
            Expanded(child: _buildInputBox("Crédito à Vista (1x)", _credit1xCtrl, Colors.orange)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentRulesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Crédito Parcelado", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                TextButton.icon(onPressed: _addRange, icon: const Icon(Icons.add_circle, size: 18), label: const Text("Add Faixa"))
              ],
            ),
            const Divider(),
            if (_installmentRanges.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Row(children: [
                  Expanded(flex: 2, child: Text("De (x)", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
                  SizedBox(width: 5),
                  Expanded(flex: 2, child: Text("Até (x)", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
                  SizedBox(width: 5),
                  Expanded(flex: 3, child: Text("Taxa (%)", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
                  SizedBox(width: 30),
                ]),
              ),
            
            ..._installmentRanges.asMap().entries.map((entry) {
              int idx = entry.key;
              InstallmentRangeRow row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildMiniInput(row.fromCtrl)),
                    const SizedBox(width: 5),
                    const Text("-", style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 5),
                    Expanded(flex: 2, child: _buildMiniInput(row.toCtrl)),
                    const SizedBox(width: 5),
                    Expanded(flex: 3, child: _buildMiniInput(row.rateCtrl, isRate: true)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _removeRange(idx))
                  ],
                ),
              );
            }).toList(),
            if (_installmentRanges.isEmpty) const Text("Nenhuma regra cadastrada.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
          ],
        ),
      ),
    );
  }

  Widget _buildAnticipationCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text("Cobrar Antecipação?", style: TextStyle(fontWeight: FontWeight.bold)),
              value: _anticipationEnabled,
              onChanged: (v) => setState(() => _anticipationEnabled = v ?? false),
              activeColor: Colors.purple,
            ),
            if (_anticipationEnabled)
              Padding(padding: const EdgeInsets.all(8), child: _buildInputBox("Taxa Mensal (%)", _anticipationRateCtrl, Colors.purple))
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox(String label, TextEditingController ctrl, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 5),
      TextFormField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: "%", contentPadding: EdgeInsets.all(12), isDense: true)),
    ]);
  }

  Widget _buildMiniInput(TextEditingController ctrl, {bool isRate = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 5), border: const OutlineInputBorder(), isDense: true, suffixText: isRate ? "%" : null),
    );
  }
}