import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import '../../ui/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment_model.dart';
import '../../models/financial_model.dart';
import '../../services/clinic_capabilities.dart';
import '../../services/package_billing.dart';
import '../../services/session_manager.dart';
import '../../services/clinical_record_service.dart';
import '../../services/whatsapp_helper.dart';
import 'widgets/charge_confirm_dialog.dart';
import 'widgets/monthly_package_card.dart';
import 'widgets/session_charge_card.dart';
import '../../utils/display.dart';
import '../../utils/external_link.dart';
import '../../widgets/page_header.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> with WidgetsBindingObserver {
  DateTime _currentMonth = DateTime.now();
  final String _filterName = "";
  bool _showMonthlyPackages = false; // Toggle para visualização de pacotes mensais (psicologia)
  
  // Controle de quem está sendo cobrado no momento para exibir o Dialog ao voltar
  String? _currentProcessingId;  String? _currentProcessingName;
  // Mensagem exata + paciente p/ registrar no prontuário no SIM.
  // Sobrevive ao dialog (limpo só no .then); NÃO = no-op puro.
  String? _pendingRecordMessage;  String? _pendingRecordPatientId;
  String? _pendingRecordPatientName;
  // Docs do pacote mensal aguardando confirmação (SIM marca; NÃO é no-op puro)
  List<DocumentSnapshot>? _pendingPackageDocs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Escuta o ciclo de vida do app
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Detecta quando o usuário volta do WhatsApp
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentProcessingId != null) {
      // Pequeno delay para garantir que a UI estabilizou
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showConfirmationDialog();
      });
    }
  }

  static const _monthlyPackagePrefix = 'monthly_package';

  void _changeMonth(int i) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + i, 1);
    });
  }

  Future<String?> _fetchPatientPhone(String patientId) async {
    final docPatient = await FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .get();
    if (!docPatient.exists) return null;
    final data = docPatient.data();
    final raw = data?['phone'] ?? data?['celular'] ?? data?['whatsapp'];
    final phone = raw?.toString().trim();
    return (phone == null || phone.isEmpty) ? null : phone;
  }

  String _formatMonthlyPeriod(String monthlyPeriod) {
    final parts = monthlyPeriod.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    return DateFormat('MMM/yyyy', 'pt_BR').format(DateTime(year, month));
  }

  bool _wasContactedToday(Map<String, dynamic> data) {
    final last = data['lastContactDate'] as Timestamp?;
    if (last == null) return false;
    final d = last.toDate();
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  // Ação de Cobrança Individual (Híbrida)
  Future<void> _handleCharge(FinancialModel item) async {
    final tab = openBlankTab();
    // 1. Busca dados atualizados do paciente (Telefone)
    final phone = await _fetchPatientPhone(item.patientId);

    if (phone == null) {
      try {
        tab?.close();
      } catch (_) {}
      if (!mounted) return;
      final isNotFound = await FirebaseFirestore.instance
          .collection('patients')
          .doc(item.patientId)
          .get()
          .then((d) => !d.exists);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isNotFound
              ? "Erro: Paciente não encontrado."
              : "Erro: Paciente sem telefone cadastrado.")));
      return;
    }

    // 2. Gera mensagem rotativa
    final message = WhatsAppHelper.getMessage(item.patientName, item.amount, item.dueDate ?? DateTime.now());

    // 3. Abre WhatsApp
    final success = await openWhatsAppSafe(context, tab,
        phone: phone, message: message);

    if (success) {
      // Marca que estamos aguardando retorno deste item
      setState(() {
        _currentProcessingId = item.id;
        _currentProcessingName = item.patientName;
        _pendingRecordMessage = message;
        _pendingRecordPatientId = item.patientId;
        _pendingRecordPatientName = item.patientName;
      });
    } else {
      toast(context, "Não foi possível abrir o WhatsApp.");
    }
  }

  // Nova ação para cobrança de pacote mensal completo
  Future<void> _handleMonthlyPackageCharge(Map<String, dynamic> packageData) async {
    final patientId = packageData['patientId'] as String;
    final patientName = packageData['patientName'] as String;
    final monthlyPeriod = packageData['monthlyPeriod'] as String;
    final totalAmount = packageData['totalAmount'] as double;
    final fullAmount =
        (packageData['fullAmount'] as num?)?.toDouble() ?? totalAmount;
    final billingDetail = packageData['billingDetail'] as String?;
    final items = packageData['items'] as List<DocumentSnapshot>;

    // Busca telefone do paciente
    final phone = await _fetchPatientPhone(patientId);
    if (phone == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Erro: Paciente não encontrado ou sem telefone.")));
      return;
    }

    // Formata período para exibição (ex: "Jan/2025")
    final periodLabel = _formatMonthlyPeriod(monthlyPeriod);

    // Dialog para escolher tipo de pagamento
    if (!mounted) return;
    html.WindowBase? chargeTab;
    final paymentType = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Cobrar Pacote $periodLabel"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Paciente: $patientName"),
            if (billingDetail != null) Text(billingDetail),
            Text(
                "Valor a cobrar: ${formatBRL(totalAmount)}"),
            if (fullAmount != totalAmount)
              Text(
                  "Valor cheio do pacote: ${formatBRL(fullAmount)}"),
            Text("${items.length} conta(s) no mês"),
            const SizedBox(height: 12),
            const Text("Como deseja cobrar?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'partial'),
            child: const Text("Pagamento Parcial", style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            onPressed: () {
              chargeTab = openBlankTab();
              Navigator.pop(ctx, 'full');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Pagar Pacote Completo"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );

    if (paymentType == null) return;

    if (paymentType == 'full') {
      // Pagar pacote completo - marca todos os itens como pagos
      await _payFullMonthlyPackage(
          items, patientName, phone, periodLabel, chargeTab);
    } else if (paymentType == 'partial') {
      // Pagamento parcial - abre dialog para valor
      await _handlePartialMonthlyPackagePayment(items, patientId, patientName, phone, periodLabel, totalAmount);
    }
  }

  Future<void> _payFullMonthlyPackage(List<DocumentSnapshot> items, String patientName, String phone, String periodLabel, html.WindowBase? tab) async {
    // Gera mensagem para WhatsApp
    final totalAmount = items.fold<double>(0.0, (total, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return total + (data['amount'] as num).toDouble();
    });

    final message = WhatsAppHelper.getMessage(patientName, totalAmount, DateTime.now());
    final success = await openWhatsAppSafe(context, tab,
        phone: phone, message: message);

    if (success) {
      // Só registra o pendente: a marcação como cobrado acontece
      // exclusivamente no SIM do dialog de confirmação (NÃO = no-op puro,
      // o pacote continua pendente e visível para cobrar de novo).
      setState(() {
        _currentProcessingId = '${_monthlyPackagePrefix}_${items.first.id}';
        _currentProcessingName = "$patientName - Pacote $periodLabel";
        _pendingRecordMessage = message;
        _pendingRecordPatientName = patientName;
        _pendingRecordPatientId =
            (items.first.data() as Map<String, dynamic>)['patientId']
                    ?.toString() ??
                '';
        _pendingPackageDocs = items;
      });
    } else {
      toast(context, "Não foi possível abrir o WhatsApp.");
    }
  }

  Future<void> _handlePartialMonthlyPackagePayment(List<DocumentSnapshot> items, String patientId, String patientName, String phone, String periodLabel, double totalAmount) async {
    final amountCtrl =
        TextEditingController(text: totalAmount.toStringAsFixed(2));
    double? amount;
    html.WindowBase? partialTab;
    try {
      if (!mounted) return;
      amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Pagamento Parcial - $periodLabel"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Paciente: $patientName"),
            Text("Total do pacote: ${formatBRL(totalAmount)}"),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Valor a receber agora",
                prefixText: "R\$ ",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
              if (val > 0 && val <= totalAmount) {
                partialTab = openBlankTab();
                Navigator.pop(ctx, val);
              }
            },
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );

      if (amount == null) return;

      // Abre WhatsApp com valor parcial
      final message =
          WhatsAppHelper.getMessage(patientName, amount, DateTime.now());
      final success = await openWhatsAppSafe(context, partialTab,
          phone: phone, message: message);

      if (success) {
        setState(() {
          _currentProcessingId =
              '${_monthlyPackagePrefix}_partial_${items.first.id}';
          _currentProcessingName = "$patientName - Parcial $periodLabel";
          _pendingRecordMessage = message;
          _pendingRecordPatientId = patientId;
          _pendingRecordPatientName = patientName;
        });
        // Para pagamento parcial, apenas registra o contato, não muda status
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in items) {
          batch.update(doc.reference, {
            'lastContactDate': FieldValue.serverTimestamp(),
            'contactHistory': FieldValue.arrayUnion([
              {
                'date': DateTime.now().toIso8601String(),
                'method': 'whatsapp_monthly_package_partial',
                'amount': amount
              }
            ])
          });
        }
        await batch.commit();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Não foi possível abrir o WhatsApp.")));
      }
    } finally {
      amountCtrl.dispose();
    }
  }

  // Dialog de Confirmação (O Humano confirma o envio)
  void _showConfirmationDialog() {
    final id = _currentProcessingId;
    final name = _currentProcessingName;

    // Limpa estado para não abrir de novo (o registro do SIM usa
    // _pendingRecord*, limpo só no .then)
    setState(() {
      _currentProcessingId = null;
      _currentProcessingName = null;
    });

    ChargeConfirmDialog.show(
      context,
      displayName: name,
      processingId: id,
      monthlyPackagePrefix: _monthlyPackagePrefix,
      onMarkCharged: _markAsCharged,
      onMarkPackageCharged: _markPackageAsCharged,
    ).then((_) {
      // Segurança: não vaza pendência entre cobranças (NÃO = no-op puro)
      _pendingPackageDocs = null;
      _pendingRecordMessage = null;
      _pendingRecordPatientId = null;
      _pendingRecordPatientName = null;
    });
  }

  /// Grava o envio confirmado no prontuário (verificação futura).
  Future<void> _recordWhatsappSent() async {
    final msg = _pendingRecordMessage;
    final pid = _pendingRecordPatientId;
    final clinicId = SessionManager().currentClinicId;
    if (msg == null || pid == null || pid.isEmpty || clinicId == null) {
      return;
    }
    try {
      await ClinicalRecordService().add(
        ClinicalRecordService.whatsappChargeRecord(
          clinicId: clinicId,
          patientId: pid,
          patientName: _pendingRecordPatientName ?? 'Paciente',
          message: msg,
          operatorName: SessionManager().userName ?? 'Operador',
          at: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Registro WhatsApp falhou: $e');
    }
  }

  /// Marca o pacote mensal como cobrado (só no SIM do dialog).
  Future<void> _markPackageAsCharged(String firstDocId) async {
    await _recordWhatsappSent();
    final docs = _pendingPackageDocs;
    _pendingPackageDocs = null;
    if (docs == null || docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      batch.update(doc.reference, {
        'status': 'cobrado',
        'lastContactDate': FieldValue.serverTimestamp(),
        'contactHistory': FieldValue.arrayUnion([
          {
            'date': DateTime.now().toIso8601String(),
            'method': 'whatsapp_monthly_package_full'
          }
        ])
      });
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pacote marcado como cobrado.")));
    }
  }

  Future<void> _markAsCharged(String financialId) async {
    await _recordWhatsappSent();
    try {
      await FirebaseFirestore.instance.collection('financial').doc(financialId).update({
        'status': 'cobrado', // Ou manter pendente e usar lastContactDate para filtrar visualmente
        'lastContactDate': FieldValue.serverTimestamp(),
        'contactHistory': FieldValue.arrayUnion([
          {'date': DateTime.now().toIso8601String(), 'method': 'whatsapp_manual'}
        ])
      });
      toast(context, "Status atualizado com sucesso!");
    } catch (e) {
      toast(context, "Erro ao atualizar status.");
    }
  }

  DateTime get _startOfMonth => DateTime(_currentMonth.year, _currentMonth.month, 1);
  DateTime get _endOfMonth => DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

  static bool _isPackageDoc(Map<String, dynamic> data) {
    if (data['billingKind'] == 'package_monthly') return true;
    if (data['billingKind'] == 'session') return false;
    return data['monthlyPeriod'] != null;
  }

  // Agrupa documentos por pacote mensal (patientId + monthlyPeriod + planId)
  Map<String, List<DocumentSnapshot>> _groupByMonthlyPackage(List<DocumentSnapshot> docs) {
    final Map<String, List<DocumentSnapshot>> groups = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final monthlyPeriod = data['monthlyPeriod'] as String?;
      if (monthlyPeriod != null) {
        final patientId = data['patientId'] as String;
        final planId = data['planId']?.toString() ?? '';
        final key = '${patientId}_${monthlyPeriod}_$planId';
        groups.putIfAbsent(key, () => []).add(doc);
      }
    }
    return groups;
  }

  (DateTime, DateTime) _monthRange(String monthlyPeriod) {
    final parts = monthlyPeriod.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month =
        parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    return (DateTime(year, month, 1), DateTime(year, month + 1, 1));
  }

  Future<PackageBill> _loadPackageBill({
    required String? planId,
    required String patientId,
    required String monthlyPeriod,
    required double packageAmount,
    required String? clinicId,
  }) async {
    final db = FirebaseFirestore.instance;
    List<AppointmentModel> sessions = [];

    if (planId != null && planId.isNotEmpty) {
      final snap = await db
          .collection('appointments')
          .where('planId', isEqualTo: planId)
          .get();
      sessions = snap.docs
          .map((d) =>
              AppointmentModel.fromMap(d.id, d.data()))
          .where((s) =>
              s.monthlyPeriod == null ||
              s.monthlyPeriod == monthlyPeriod)
          .toList();
    }

    if (sessions.isEmpty) {
      final (start, end) = _monthRange(monthlyPeriod);
      Query query = db
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end));
      if (clinicId != null && clinicId.isNotEmpty) {
        query = query.where('clinicId', isEqualTo: clinicId);
      }
      final snap = await query.get();
      sessions = snap.docs
          .map((d) => AppointmentModel.fromMap(
              d.id, d.data() as Map<String, dynamic>))
          .toList();
    }

    double discount = 0.0;
    if (planId != null && planId.isNotEmpty) {
      try {
        final planDoc = await db
            .collection('treatment_plans')
            .doc(planId)
            .get();
        final raw = planDoc.data()?['thirdPartyDiscount'];
        discount =
            raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;
      } catch (_) {
        discount = 0.0; // Plano excluído ou sem acesso.
      }
    }

    return PackageBilling.compute(
      packageAmount: packageAmount,
      discount: discount,
      sessions: sessions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager().currentClinicId;
    final caps = ClinicCapabilities.current();
    final isPsychology = caps.isPsychology;

    // Período atual no formato "YYYY-MM" para filtrar pacotes mensais
    final String currentPeriod = "${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}";

    // Query base
    final baseQuery = FirebaseFirestore.instance.collection('financial')
        .where('clinicId', isEqualTo: clinicId)
        .where('status', whereIn: ['pendente', 'pending'])
        .where('type', isEqualTo: 'income');

    // Query condicional: por monthlyPeriod (pacotes) ou por dueDate (sessões)
    final query = _showMonthlyPackages && isPsychology
        ? baseQuery.where('monthlyPeriod', isEqualTo: currentPeriod)
        : baseQuery.where('dueDate', isGreaterThanOrEqualTo: _startOfMonth)
            .where('dueDate', isLessThanOrEqualTo: _endOfMonth);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Cobrança Manual Inteligente", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(),
        actions: [
          if (isPsychology)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Text(_showMonthlyPackages ? "Pacotes Mensais" : "Por Sessão", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Switch(
                    value: _showMonthlyPackages,
                    onChanged: (val) => setState(() => _showMonthlyPackages = val),
                    activeThumbColor: Colors.purple,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filtros de Mês (pílula padrão)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: MonthSelectorPill(
              date: _currentMonth,
              onPrev: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
          ),
          
          const SizedBox(height: 8),

          // Lista de Cobrança
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                   return Center(child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.check_circle, size: 60, color: Colors.green[200]),
                       const SizedBox(height: 10),
                       const Text("Tudo em dia! Nenhuma cobrança pendente.", style: TextStyle(color: Colors.grey)),
                     ],
                   ));
                }

                // Filtragem local por nome (se necessário)
                final filteredDocs = docs.where((doc) {
                   final data = doc.data() as Map<String, dynamic>;
                   final name = (data['patientName'] ?? '').toString().toLowerCase();
                   return name.contains(_filterName.toLowerCase());
                }).toList();

                // Se for visualização de pacotes mensais e for clínica de psicologia
                if (_showMonthlyPackages && isPsychology) {
                  final monthlyGroups = _groupByMonthlyPackage(filteredDocs);
                  
                  if (monthlyGroups.isEmpty) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.psychology, size: 60, color: Colors.purple[200]),
                        const SizedBox(height: 10),
                        const Text("Nenhum pacote mensal pendente.", style: TextStyle(color: Colors.grey)),
                      ],
                    ));
                  }

                  // Converte grupos para lista ordenada
                  final groupEntries = monthlyGroups.entries.toList();
                  groupEntries.sort((a, b) {
                    final aData = a.value.first.data() as Map<String, dynamic>;
                    final bData = b.value.first.data() as Map<String, dynamic>;
                    final aDueDate = (aData['dueDate'] as Timestamp).toDate();
                    final bDueDate = (bData['dueDate'] as Timestamp).toDate();
                    return aDueDate.compareTo(bDueDate);
                  });

                  return ListView.builder(
                    itemCount: groupEntries.length,
                    itemBuilder: (context, index) {
                      final entry = groupEntries[index];
                      final items = entry.value;
                      final firstItem = items.first;
                      final data = firstItem.data() as Map<String, dynamic>;

                      final patientId = data['patientId'] as String;
                      final patientName = data['patientName'] as String;
                      final monthlyPeriod = data['monthlyPeriod'] as String;
                      final installmentNumber =
                          data['installmentNumber'] as String? ?? '';
                      final planId = data['planId']?.toString();

                      // Valor cheio do pacote mensal (soma dos docs do grupo)
                      final packageAmount = items.fold<double>(0.0, (total, doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return total + (d['amount'] as num).toDouble();
                      });

                      // Verifica se algum foi contatado hoje
                      final contactedToday = items.any((doc) =>
                          _wasContactedToday(
                              doc.data() as Map<String, dynamic>));

                      // Formata período para exibição (ex: "Jan/2025")
                      final periodLabel =
                          _formatMonthlyPeriod(monthlyPeriod);

                      return FutureBuilder<PackageBill>(
                        future: _loadPackageBill(
                          planId: planId,
                          patientId: patientId,
                          monthlyPeriod: monthlyPeriod,
                          packageAmount: packageAmount,
                          clinicId: clinicId,
                        ).timeout(const Duration(seconds: 5)),
                        builder: (context, billSnap) {
                          if (billSnap.connectionState ==
                              ConnectionState.waiting) {
                            return MonthlyPackageCard(
                              patientName: patientName,
                              periodLabel: periodLabel,
                              installmentNumber: installmentNumber,
                              sessionCount: items.length,
                              dueDate: (data['dueDate'] as Timestamp)
                                  .toDate(),
                              totalAmount: packageAmount,
                              contactedToday: contactedToday,
                              billingLoading: true,
                              onTap: () {},
                            );
                          }
                          if (billSnap.hasError || !billSnap.hasData) {
                            return MonthlyPackageCard(
                              patientName: patientName,
                              periodLabel: periodLabel,
                              installmentNumber: installmentNumber,
                              sessionCount: items.length,
                              dueDate: (data['dueDate'] as Timestamp)
                                  .toDate(),
                              totalAmount: packageAmount,
                              fullAmount: packageAmount,
                              billingDetail:
                                  "Cálculo indisponível no momento",
                              contactedToday: contactedToday,
                              onTap: () => _handleMonthlyPackageCharge({
                                'patientId': patientId,
                                'patientName': patientName,
                                'monthlyPeriod': monthlyPeriod,
                                'totalAmount': packageAmount,
                                'fullAmount': packageAmount,
                                'billingDetail': null,
                                'items': items,
                              }),
                            );
                          }
                          final bill = billSnap.data!;
                          final totalAmount = bill.amountDue;
                          final detail = bill == null
                              ? null
                              : "${bill.describe()} • ${formatBRL(bill.amountDue)}"
                                  "${bill.isPartial ? " (parcial)" : ""}";

                          return MonthlyPackageCard(
                            patientName: patientName,
                            periodLabel: periodLabel,
                            installmentNumber: installmentNumber,
                            sessionCount:
                                bill?.previstas ?? items.length,
                            dueDate:
                                (data['dueDate'] as Timestamp).toDate(),
                            totalAmount: totalAmount,
                            fullAmount: packageAmount,
                            billingDetail: detail,
                            isPartial: bill?.isPartial ?? false,
                            contactedToday: contactedToday,
                            onTap: () => _handleMonthlyPackageCharge({
                              'patientId': patientId,
                              'patientName': patientName,
                              'monthlyPeriod': monthlyPeriod,
                              'totalAmount': totalAmount,
                              'fullAmount': packageAmount,
                              'billingDetail': detail,
                              'items': items,
                            }),
                          );
                        },
                      );
                    },
                  );
                }

                // Visualização padrão por sessão (pacotes não entram aqui)
                final sessionDocs = filteredDocs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return !_isPackageDoc(d);
                }).toList();

                if (sessionDocs.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 60, color: Colors.green[200]),
                      const SizedBox(height: 10),
                      const Text(
                          "Tudo em dia! Nenhuma cobrança pendente.",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ));
                }

                return ListView.builder(
                  itemCount: sessionDocs.length,
                  itemBuilder: (context, index) {
                    final data = sessionDocs[index].data() as Map<String, dynamic>;
                    final item = FinancialModel.fromMap(sessionDocs[index].id, data);

                    // Verifica se já foi contatado hoje (opcional, para UI)
                    final contactedToday = _wasContactedToday(data);

                    return SessionChargeCard(
                      item: item,
                      contactedToday: contactedToday,
                      onTap: () => _handleCharge(item),
                      paymentNoticed:
                          (data['avisoPagamento'] as Map?) != null,
                      onDismissNotice: () => FirebaseFirestore.instance
                          .collection('financial')
                          .doc(item.id)
                          .update({'avisoPagamento': FieldValue.delete()}),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}