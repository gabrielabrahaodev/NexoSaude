import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../ui/app_theme.dart';
// ADICIONE ESTE IMPORT
import '../../services/session_manager.dart';
import '../../services/portal_mirror.dart';
import '../../services/clinic_capabilities.dart';
import '../../models/therapeutic_status.dart';
import '../../utils/display.dart';

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

  /// Aceite LGPD p/ link de acompanhamento (portal/WhatsApp). Default
  /// desmarcado (consentimento livre); sem aceite, sem token no cadastro.
  bool _lgpdPortalConsent = false;

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    // --- SEGREGAÇÃO DE DADOS ---
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) {
       toast(context, "Erro: Sessão inválida.", error: true);
       return;
    }

    setState(() => _isLoading = true);

  
    try {
      // Sem validação de CPF (decisão 01/10/2026): aceita qualquer valor,
      // inclusive vazio ou duplicado.

      // Salva com o carimbo da clínica.
      // Psicologia: grava o estágio terapêutico escolhido (kanban lê direto).
      // Dental: 'Ativo' (campo invisível, lista não depende dele).
      final isPsy = ClinicCapabilities.current().isPsychology;
      final newRef = await FirebaseFirestore.instance.collection('patients').add({
        'clinicId': clinicId, // CAMPO OBRIGATÓRIO NOVO
        'portalToken': _lgpdPortalConsent ? newPortalToken() : '',
        'lgpdPortalConsent': {
          'accepted': _lgpdPortalConsent,
          'at': FieldValue.serverTimestamp(),
        },
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'cpf': _cpfController.text.trim(),
        'rg': _rgController.text.trim(),
        'birthDate': _birthController.text.trim(),
        'birthMonth': birthMonthOf(_birthController.text.trim()),
        'address': _addressController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': isPsy ? _therapeuticStatus.storage : 'Ativo',
        'searchKey': _nameController.text.trim().toLowerCase(),
      });
      // Espelho inicial: link vale desde o cadastro (best-effort).
      await PortalMirrorSync.patient(newRef.id);

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
                      // Sem validator de CPF (decisão 01/10/2026).
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

              CheckboxListTile(
                value: _lgpdPortalConsent,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                    "Autorização LGPD — link de acompanhamento (portal/WhatsApp)",
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                    "Autoriza contato por WhatsApp e link do portal com agendamentos e pagamentos. Sem aceite, o link só é gerado depois, na aba Cadastro.",
                    style: TextStyle(fontSize: 12)),
                onChanged: (v) =>
                    setState(() => _lgpdPortalConsent = v ?? false),
              ),
              const SizedBox(height: 16),

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