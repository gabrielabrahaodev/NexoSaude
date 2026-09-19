import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../ui/app_theme.dart';
// ADICIONE ESTE IMPORT
import '../../services/session_manager.dart';
import '../../services/clinic_capabilities.dart';
import '../../models/therapeutic_status.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key});

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController();
  final _birthController = TextEditingController();
  final _addressController = TextEditingController();

  // Status terapêutico (só psicologia; dental ignora e grava 'Ativo')
  TherapeuticStatus _therapeuticStatus = TherapeuticStatus.lead;

  // --- MÁSCARAS ---
  final maskPhone = MaskTextInputFormatter(
    mask: '(##) #####-####', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy,
  );
  
  final maskCPF = MaskTextInputFormatter(
    mask: '###.###.###-##', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy,
  );
  
  final maskDate = MaskTextInputFormatter(
    mask: '##/##/####', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy,
  );

  bool _isLoading = false;

  bool _isValidCPF(String? cpf) {
    /*
    if (cpf == null) return false;
    var numbers = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.length != 11) return false;
    if (RegExp(r'^(\d)\1*$').hasMatch(numbers)) return false; 
    List<int> digits = numbers.split('').map((String d) => int.parse(d)).toList();
    int calcDv1 = 0;
    for (int i = 0; i < 9; i++) { calcDv1 += digits[i] * (10 - i); }
    int dv1 = 11 - (calcDv1 % 11);
    if (dv1 >= 10) dv1 = 0;
    if (digits[9] != dv1) return false;
    int calcDv2 = 0;
    for (int i = 0; i < 10; i++) { calcDv2 += digits[i] * (11 - i); }
    int dv2 = 11 - (calcDv2 % 11);
    if (dv2 >= 10) dv2 = 0;
    if (digits[10] != dv2) return false;
    */
    return true;
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    // --- SEGREGAÇÃO DE DADOS ---
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Sessão inválida."), backgroundColor: Colors.red));
       return;
    }

    setState(() => _isLoading = true);

  
    try {
      // Verifica duplicidade de CPF (APENAS NA CLÍNICA ATUAL)
      final cpfQuery = await FirebaseFirestore.instance
          .collection('patients')
          .where('clinicId', isEqualTo: clinicId) // Só importa se já existe AQUI
          .where('cpf', isEqualTo: _cpfController.text.trim())
          .get();
      /*
      if (cpfQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro: Este CPF já está cadastrado nesta clínica."), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
        return;
      }*/

      // Salva com o carimbo da clínica.
      // Psicologia: grava o estágio terapêutico escolhido (kanban lê direto).
      // Dental: 'Ativo' (campo invisível, lista não depende dele).
      final isPsy = ClinicCapabilities.current().isPsychology;
      await FirebaseFirestore.instance.collection('patients').add({
        'clinicId': clinicId, // CAMPO OBRIGATÓRIO NOVO
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'cpf': _cpfController.text.trim(),
        'rg': _rgController.text.trim(),
        'birthDate': _birthController.text.trim(),
        'address': _addressController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': isPsy ? _therapeuticStatus.storage : 'Ativo',
        'searchKey': _nameController.text.trim().toLowerCase(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paciente cadastrado com sucesso!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Paciente"),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Dados Pessoais", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                inputFormatters: [maskPhone],
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Telefone / WhatsApp", hintText: "(00) 00000-0000", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                validator: (value) => value == null || value.length < 14 ? 'Telefone inválido' : null,
              ),
              const SizedBox(height: 24),

              const Text("Documentação (Obrigatório para Nota Fiscal/IR)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rgController,
                      decoration: const InputDecoration(labelText: "RG", border: OutlineInputBorder(), prefixIcon: Icon(Icons.assignment_ind)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cpfController,
                      inputFormatters: [maskCPF],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "CPF", hintText: "000.000.000-00", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Obrigatório';
                        if (!_isValidCPF(value)) return 'CPF Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _birthController,
                inputFormatters: [maskDate],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Data de Nascimento", hintText: "DD/MM/AAAA", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
              ),
              const SizedBox(height: 24),

              const Text("Localização", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),

              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Endereço Completo", hintText: "Rua, Número, Bairro, Cidade...", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on), alignLabelWithHint: true),
              ),

              const SizedBox(height: 32),

              // Só psicologia escolhe o estágio (default: Prospecto).
              // Dental não vê este campo e grava 'Ativo'.
              if (ClinicCapabilities.current().isPsychology) ...[
                const Text("Status Terapêutico",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                DropdownButtonFormField<TherapeuticStatus>(
                  value: _therapeuticStatus,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.psychology),
                  ),
                  items: TherapeuticStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _therapeuticStatus = v);
                  },
                ),
                const SizedBox(height: 32),
              ],

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePatient,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CADASTRAR PACIENTE"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}