import 'dart:async'; // Necessário para o StreamSubscription
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../../ui/app_theme.dart';

class AnamnesisTab extends StatefulWidget {
  final String patientId;

  const AnamnesisTab({super.key, required this.patientId});

  @override
  State<AnamnesisTab> createState() => _AnamnesisTabState();
}

class _AnamnesisTabState extends State<AnamnesisTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _anamnesisSubscription; // Variável para controlar o "ouvido"

  // --- ESTADO DO FORMULÁRIO ---
  bool _underMedicalTreatment = false;
  String _medicalTreatmentDesc = '';
  
  bool _takingMedication = false;
  String _medicationDesc = '';
  
  bool _hasAllergies = false;
  String _allergiesDesc = '';

  Map<String, bool> _conditions = {
    'Diabetes': false,
    'Hipertensão (Pressão Alta)': false,
    'Problemas Cardíacos': false,
    'Problemas Renais': false,
    'Problemas Gástricos': false,
    'Problemas Respiratórios/Asma': false,
    'Hepatite / Icterícia': false,
    'HIV / AIDS': false,
    'Anemia': false,
    'Problemas de Coagulação': false,
  };

  bool _smoker = false;
  bool _alcohol = false;
  bool _bruxism = false;
  bool _pregnant = false; 
  
  String _observations = '';

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener(); // Inicia a escuta em tempo real
  }

  @override
  void dispose() {
    _anamnesisSubscription?.cancel(); // IMPORTANTE: Desliga o ouvinte ao sair da tela
    super.dispose();
  }

  // --- 1. ESCUTA EM TEMPO REAL (MUDANÇA PRINCIPAL) ---
  void _setupRealtimeListener() {
    final docRef = FirebaseFirestore.instance.collection('anamnesis').doc(widget.patientId);

    // snapshots() avisa sempre que algo muda no banco
    _anamnesisSubscription = docRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        
        // Atualiza a tela automaticamente
        if (mounted) {
          setState(() {
            _underMedicalTreatment = data['underMedicalTreatment'] ?? false;
            _medicalTreatmentDesc = data['medicalTreatmentDesc'] ?? '';
            _takingMedication = data['takingMedication'] ?? false;
            _medicationDesc = data['medicationDesc'] ?? '';
            _hasAllergies = data['hasAllergies'] ?? false;
            _allergiesDesc = data['allergiesDesc'] ?? '';
            
            _smoker = data['smoker'] ?? false;
            _alcohol = data['alcohol'] ?? false;
            _bruxism = data['bruxism'] ?? false;
            _pregnant = data['pregnant'] ?? false;
            _observations = data['observations'] ?? '';

            // Atualiza checkboxes
            if (data['conditions'] != null) {
              Map<String, dynamic> loadedConditions = data['conditions'];
              _conditions.forEach((key, val) {
                if (loadedConditions.containsKey(key)) {
                  _conditions[key] = loadedConditions[key];
                }
              });
            }
            
            _isLoading = false;
          });
        }
      } else {
        // Se o documento não existe (primeira vez), apenas para o loading
        if (mounted) setState(() => _isLoading = false);
      }
    }, onError: (error) {
      debugPrint("Erro no listener: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // --- 2. SALVAR DADOS ---
  Future<void> _saveAnamnesis() async {
    if (!_formKey.currentState!.validate()) return;

    // Loading visual apenas para feedback de salvamento manual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Salvando..."), duration: Duration(milliseconds: 800))
    );

    try {
      await FirebaseFirestore.instance.collection('anamnesis').doc(widget.patientId).set({
        'patientId': widget.patientId,
        'updatedAt': FieldValue.serverTimestamp(),
        'underMedicalTreatment': _underMedicalTreatment,
        'medicalTreatmentDesc': _medicalTreatmentDesc,
        'takingMedication': _takingMedication,
        'medicationDesc': _medicationDesc,
        'hasAllergies': _hasAllergies,
        'allergiesDesc': _allergiesDesc,
        'conditions': _conditions,
        'smoker': _smoker,
        'alcohol': _alcohol,
        'bruxism': _bruxism,
        'pregnant': _pregnant,
        'observations': _observations,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Anamnese salva/atualizada!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- 3. ENVIAR POR WHATSAPP ---
  Future<void> _sendLinkToWhatsapp() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).get();
      String? phoneRaw;
      String patientName = "Paciente";

      if (doc.exists) {
        final data = doc.data()!;
        phoneRaw = data['phone'] ?? data['celular'] ?? data['whatsapp'];
        patientName = data['name'] ?? "Paciente";
      }

      if (phoneRaw == null || phoneRaw.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Telefone não cadastrado.")));
        return;
      }

      String phone = phoneRaw.replaceAll(RegExp(r'[^\d]'), '');
      if (!phone.startsWith('55')) phone = '55$phone';

      String baseUrl = "https://odontocontrole-1c701.web.app/anamnese.html"; 
      String link = "$baseUrl?id=${widget.patientId}";

      String message = "Olá $patientName, para agilizar seu atendimento, por favor preencha sua ficha de anamnese online clicando neste link: $link";

      final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o WhatsApp.")));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Ficha de Anamnese", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[50],
        elevation: 0,
        automaticallyImplyLeading: false, 
        actions: [
          TextButton.icon(
            onPressed: _sendLinkToWhatsapp,
            icon: const Icon(Icons.share, color: Colors.green, size: 20),
            label: const Text("ENVIAR P/ PACIENTE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            style: TextButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAnamnesis,
        label: const Text("SALVAR"),
        icon: const Icon(Icons.save),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SAÚDE GERAL
              _buildSectionTitle("Estado Geral de Saúde"),
              _buildYesNoField(
                label: "Está sob tratamento médico atualmente?",
                value: _underMedicalTreatment,
                onChanged: (val) => setState(() => _underMedicalTreatment = val),
                detailsController: _underMedicalTreatment ? TextEditingController(text: _medicalTreatmentDesc) : null,
                onDetailsChanged: (val) => _medicalTreatmentDesc = val,
                hintText: "Qual tratamento? Qual médico?",
              ),
              const Divider(),
              _buildYesNoField(
                label: "Toma algum medicamento de uso contínuo?",
                value: _takingMedication,
                onChanged: (val) => setState(() => _takingMedication = val),
                detailsController: _takingMedication ? TextEditingController(text: _medicationDesc) : null,
                onDetailsChanged: (val) => _medicationDesc = val,
                hintText: "Quais medicamentos e dosagem?",
              ),
              const Divider(),
              _buildYesNoField(
                label: "Possui alergia a medicamentos ou materiais?",
                value: _hasAllergies,
                onChanged: (val) => setState(() => _hasAllergies = val),
                detailsController: _hasAllergies ? TextEditingController(text: _allergiesDesc) : null,
                onDetailsChanged: (val) => _allergiesDesc = val,
                hintText: "Penicilina? Dipirona? Látex? Anestésico?",
              ),

              const SizedBox(height: 25),
              
              // 2. HISTÓRICO
              _buildSectionTitle("Histórico Patológico"),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!)
                ),
                child: Column(
                  children: _conditions.keys.map((key) {
                    return CheckboxListTile(
                      title: Text(key, style: const TextStyle(fontSize: 14)),
                      value: _conditions[key],
                      dense: true,
                      activeColor: Colors.red,
                      onChanged: (val) => setState(() => _conditions[key] = val!),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 25),
              
              // 3. HÁBITOS
              _buildSectionTitle("Hábitos e Outros"),
              SwitchListTile(
                title: const Text("Fumante?"),
                value: _smoker,
                activeColor: Colors.orange,
                onChanged: (val) => setState(() => _smoker = val),
              ),
              SwitchListTile(
                title: const Text("Consome álcool com frequência?"),
                value: _alcohol,
                activeColor: Colors.orange,
                onChanged: (val) => setState(() => _alcohol = val),
              ),
              SwitchListTile(
                title: const Text("Bruxismo / Aperta os dentes?"),
                value: _bruxism,
                activeColor: Colors.orange,
                onChanged: (val) => setState(() => _bruxism = val),
              ),
              SwitchListTile(
                title: const Text("Gestante ou Lactante?"),
                subtitle: const Text("Apenas para mulheres"),
                value: _pregnant,
                activeColor: Colors.orange,
                onChanged: (val) => setState(() => _pregnant = val),
              ),

              const SizedBox(height: 25),
              
              // 4. OBSERVAÇÕES
              _buildSectionTitle("Observações Adicionais"),
              TextFormField(
                key: Key(_observations), // Truque para forçar rebuild se o texto vier do servidor
                initialValue: _observations,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Outras cirurgias, internações recentes, queixas principais...",
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => _observations = val,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildYesNoField({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    TextEditingController? detailsController,
    Function(String)? onDetailsChanged,
    String? hintText,
  }) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          value: value,
          activeColor: Colors.red,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
        ),
        if (value) // Simplifiquei aqui para criar o controller dinamicamente na view se necessário, mas o state trata isso
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            child: TextFormField(
              // Usamos Key para garantir que o Flutter redesenhe se o valor mudar via Stream
              key: Key(value.toString() + (detailsController?.text ?? "")), 
              initialValue: detailsController?.text,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                filled: true,
                fillColor: Colors.red[50], 
                border: const OutlineInputBorder(),
              ),
              onChanged: onDetailsChanged,
            ),
          )
      ],
    );
  }
}