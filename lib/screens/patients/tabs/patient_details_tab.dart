import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../ui/app_theme.dart';

class PatientDetailsTab extends StatefulWidget {
  final String patientName;
  final String patientId; 
  const PatientDetailsTab({super.key, required this.patientName, required this.patientId});

  @override
  State<PatientDetailsTab> createState() => _PatientDetailsTabState();
}

class _PatientDetailsTabState extends State<PatientDetailsTab> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _rgCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final maskPhone = MaskTextInputFormatter(mask: '(##) #####-####', filter: { "#": RegExp(r'[0-9]') }, type: MaskAutoCompletionType.lazy);
  final maskCPF = MaskTextInputFormatter(mask: '###.###.###-##', filter: { "#": RegExp(r'[0-9]') }, type: MaskAutoCompletionType.lazy);
  final maskDate = MaskTextInputFormatter(mask: '##/##/####', filter: { "#": RegExp(r'[0-9]') }, type: MaskAutoCompletionType.lazy);

  Future<void> _updatePatient(String docId) async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('patients').doc(docId).update({
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'cpf': _cpfCtrl.text.trim(),
          'rg': _rgCtrl.text.trim(),
          'birthDate': _birthCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'searchKey': _nameCtrl.text.trim().toLowerCase(),
        });
        
        setState(() => _isEditing = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cadastro atualizado com sucesso!")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao atualizar: $e"), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Validamos se o ID é válido antes de buscar
    if (widget.patientId.isEmpty) {
      return const Center(child: Text("ID do paciente inválido ou não informado."));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. TRATAMENTO DE ERRO (Correção Principal)
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                const Text("Erro ao carregar dados.", style: TextStyle(color: Colors.red)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          );
        }

        // 2. INDICADOR DE CARREGAMENTO
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 3. VERIFICAÇÃO DE EXISTÊNCIA
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text("Paciente não encontrado no banco de dados (ID: ${widget.patientId})."));
        }

        var doc = snapshot.data!;
        var data = doc.data() as Map<String, dynamic>;

        // Preenche os campos apenas se não estiver editando para não sobrescrever o que o usuário digita
        if (!_isEditing) {
          _nameCtrl.text = data['name'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _cpfCtrl.text = data['cpf'] ?? '';
          _rgCtrl.text = data['rg'] ?? '';
          _birthCtrl.text = data['birthDate'] ?? data['birth'] ?? '';
          _addressCtrl.text = data['address'] ?? '';
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Dados Cadastrais", style: AppTextStyles.h2),
                    TextButton.icon(
                      icon: Icon(_isEditing ? Icons.cancel : Icons.edit, size: 18, color: _isEditing ? AppColors.danger : AppColors.primary),
                      label: Text(_isEditing ? "Cancelar" : "Editar", style: TextStyle(color: _isEditing ? AppColors.danger : AppColors.primary)),
                      onPressed: () => setState(() => _isEditing = !_isEditing),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),
                
                // Campos
                const Text("Pessoal", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                TextFormField(controller: _nameCtrl, enabled: _isEditing, textCapitalization: TextCapitalization.words, decoration: _buildDecoration("Nome Completo", Icons.person), validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _phoneCtrl, enabled: _isEditing, inputFormatters: [maskPhone], keyboardType: TextInputType.phone, decoration: _buildDecoration("Telefone", Icons.phone)),
                
                const SizedBox(height: 24),
                const Text("Documentação", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(controller: _rgCtrl, enabled: _isEditing, decoration: _buildDecoration("RG", Icons.assignment_ind))), 
                  const SizedBox(width: 16), 
                  Expanded(child: TextFormField(controller: _cpfCtrl, enabled: _isEditing, inputFormatters: [maskCPF], keyboardType: TextInputType.number, decoration: _buildDecoration("CPF", Icons.badge)))
                ]),
                const SizedBox(height: 16),
                TextFormField(controller: _birthCtrl, enabled: _isEditing, inputFormatters: [maskDate], keyboardType: TextInputType.number, decoration: _buildDecoration("Data Nasc.", Icons.calendar_today)),
                
                const SizedBox(height: 24),
                const Text("Localização", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                TextFormField(controller: _addressCtrl, enabled: _isEditing, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: _buildDecoration("Endereço Completo", Icons.location_on)),
                
                if (_isEditing) ...[
                  const SizedBox(height: 30), 
                  SizedBox(
                    height: 50, 
                    child: ElevatedButton.icon(
                      onPressed: () => _updatePatient(doc.id), 
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), 
                      icon: const Icon(Icons.save), 
                      label: const Text("SALVAR ALTERAÇÕES")
                    )
                  ), 
                  const SizedBox(height: 20)
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _buildDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label, 
      prefixIcon: Icon(icon, color: _isEditing ? AppColors.primary : Colors.grey), 
      border: const OutlineInputBorder(), 
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)), 
      disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)), 
      filled: !_isEditing,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
    );
  }
}