import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../services/portal_mirror.dart';
import '../../../services/remarcacao_service.dart' show portalUrl;
import '../../../ui/app_theme.dart';
import '../../../utils/display.dart';

class PatientDetailsTab extends StatefulWidget {
  final String patientName;
  final String patientId; 
  const PatientDetailsTab({super.key, required this.patientName, required this.patientId});

  @override
  State<PatientDetailsTab> createState() => _PatientDetailsTabState();
}

class _PatientDetailsTabState extends State<PatientDetailsTab> {
  bool _isEditing = false;
  bool _workingLink = false;
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

  /// Gera (ou revoga e gera de novo) o link do portal. Revogar mata o
  /// link antigo: apaga o espelho velho e sincroniza o novo.
  /// Só chega aqui com aceite confirmado (diálogo LGPD): registra
  /// aceite com origem (balcão) e quem colheu.
  Future<void> _rotatePortalLink(String docId, String? oldToken) async {
    setState(() => _workingLink = true);
    try {
      final token = newPortalToken();
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(docId)
          .update({
        'portalToken': token,
        // Aceite colhido pelo atendente no balcão (diálogo explícito).
        'lgpdPortalConsent': {
          'accepted': true,
          'at': FieldValue.serverTimestamp(),
          'via': 'balcao',
          'by': FirebaseAuth.instance.currentUser?.uid ?? '',
        },
      });
      if ((oldToken ?? '').isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('portal')
            .doc(oldToken)
            .delete()
            .catchError((_) {});
      }
      await PortalMirrorSync.patient(docId);
      if (mounted) toast(context, "Link do portal pronto.", ok: true);
    } catch (e) {
      if (mounted) toast(context, "Falha ao gerar link: $e", error: true);
    } finally {
      if (mounted) setState(() => _workingLink = false);
    }
  }

  /// Geração exige aceite explícito: sem "Sim", nada é gravado.
  Future<void> _confirmConsentAndGenerate(
      String docId, String? oldToken) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Autorização LGPD"),
        content: const Text(
            "O paciente autorizou o link do portal/WhatsApp (ver agendamentos e pagamentos)? Sem autorização, nenhum link é gerado."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Não autorizou")),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text("Sim, autorizou")),
        ],
      ),
    );
    if (ok == true) await _rotatePortalLink(docId, oldToken);
  }

  /// Revogar = matar o acesso (direito de revogação LGPD): apaga o
  /// espelho, limpa o token e marca accepted:false. Novo link só com
  /// novo aceite.
  Future<void> _confirmRevoke(String docId, String oldToken) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Revogar link?"),
        content: const Text(
            "O link para de funcionar na hora e o aceite LGPD é retirado. Para novo acesso, gere outro link com autorização."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text("Revogar acesso")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _workingLink = true);
    try {
      await FirebaseFirestore.instance
          .collection('portal')
          .doc(oldToken)
          .delete()
          .catchError((_) {});
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(docId)
          .update({
        'portalToken': '',
        'lgpdPortalConsent': {
          'accepted': false,
          'revokedAt': FieldValue.serverTimestamp(),
        },
      });
      if (mounted) toast(context, "Acesso ao portal revogado.", ok: true);
    } catch (e) {
      if (mounted) toast(context, "Falha ao revogar: $e", error: true);
    } finally {
      if (mounted) setState(() => _workingLink = false);
    }
  }

  Future<void> _updatePatient(String docId) async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('patients').doc(docId).update({
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'cpf': _cpfCtrl.text.trim(),
          'rg': _rgCtrl.text.trim(),
          'birthDate': _birthCtrl.text.trim(),
          'birthMonth': birthMonthOf(_birthCtrl.text.trim()),
          'address': _addressCtrl.text.trim(),
          'searchKey': _nameCtrl.text.trim().toLowerCase(),
        });
        
        setState(() => _isEditing = false);
        if (mounted) toast(context, "Cadastro atualizado com sucesso!");
      } catch (e) {
        if (mounted) toast(context, "Erro ao atualizar: $e");
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
                ],

                // ---------- PORTAL DO PACIENTE ----------
                const SizedBox(height: 10),
                const Text("Portal do paciente",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                _portalSection(
                    doc.id,
                    '${data['portalToken'] ?? ''}',
                    (data['lgpdPortalConsent'] as Map?)?['accepted']
                        as bool?,
                    (data['lgpdPortalConsent'] as Map?)?['at']),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Link do portal: sem aceite não há link nem cópia. Com aceite:
  /// gerar (com diálogo), copiar ou revogar (retira o aceite).
  Widget _portalSection(
      String docId, String token, bool? consented, dynamic consentAt) {
    final hasConsent = consented == true;
    if (token.isEmpty || !hasConsent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                token.isEmpty
                    ? "Sem aceite LGPD. O link só é gerado com autorização do paciente."
                    : "Link suspenso: sem aceite LGPD vigente. Gere outro com autorização.",
                style: const TextStyle(
                    fontSize: 12, fontStyle: FontStyle.italic)),
          ),
          OutlinedButton.icon(
            onPressed: _workingLink
                ? null
                : () => _confirmConsentAndGenerate(
                    docId, token.isEmpty ? null : token),
            icon: const Icon(Icons.link_outlined),
            label: Text(
                _workingLink ? "Gerando..." : "Gerar link do portal"),
          ),
        ],
      );
    }
    final link = portalUrl(token);
    final at = consentAt is Timestamp ? consentAt.toDate() : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (at != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text("Aceite LGPD em ${formatDateFull(at)}",
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey)),
              ),
            SelectableText(link,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      toast(context, "Link copiado.");
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text("Copiar link"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _workingLink
                        ? null
                        : () => _confirmRevoke(docId, token),
                    icon: const Icon(Icons.refresh,
                        size: 18, color: Colors.red),
                    label: const Text("Revogar",
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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