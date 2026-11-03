import '../../utils/report_export.dart' show reportMoney;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/collection_queue.dart';
import '../../services/collection_queue_service.dart';
import '../../services/session_manager.dart';
import '../../utils/collection_export.dart';
import '../../utils/display.dart';
import '../../utils/external_link.dart';
import '../../utils/patient_route.dart';
import '../patients/tabs/patient_financial_tab.dart';
import 'clinical_collections_view.dart';

class ClinicalCollectionsScreen extends StatefulWidget {
  const ClinicalCollectionsScreen({super.key});
  @override
  State<ClinicalCollectionsScreen> createState() =>
      _ClinicalCollectionsScreenState();
}

class _ClinicalCollectionsScreenState extends State<ClinicalCollectionsScreen> {
  final _service = CollectionQueueService();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<List<CollectionClinic>> _clinics;
  Stream<CollectionQueue>? _stream;
  bool _busy = false;
  String? _user;
  @override
  void initState() {
    super.initState();
    _user = SessionManager().userId;
    _clinics = _load();
    SessionManager().addListener(_sessionChanged);
  }

  Future<List<CollectionClinic>> _load() async {
    final clinics = await _service.clinics();
    if (mounted && SessionManager().userId == _user) {
      _stream = _service.watch(clinics, _month);
    }
    return clinics;
  }

  void _sessionChanged() {
    if (_user != SessionManager().userId && mounted) {
      setState(() {
        _user = SessionManager().userId;
        _stream = null;
        _clinics = _load();
      });
    }
  }

  @override
  void dispose() {
    SessionManager().removeListener(_sessionChanged);
    super.dispose();
  }

  void _retry() => setState(() {
    _stream = null;
    _clinics = _load();
  });
  void _changeMonth(int i, List<CollectionClinic> clinics) => setState(() {
    _month = DateTime(_month.year, _month.month + i);
    _stream = _service.watch(clinics, _month);
  });
  bool get _alive => mounted && _user == SessionManager().userId;
  Future<void> _copy(CollectionCharge c) async {
    try {
      await Clipboard.setData(ClipboardData(text: c.message(DateTime.now())));
      if (mounted && _alive) toast(context, 'Texto copiado.');
    } catch (_) {
      if (mounted && _alive) toast(context, 'Não foi possível copiar o texto.');
    }
  }

  Future<bool?> _confirm(
    String title,
    String text, {
    String action = 'Confirmar',
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Não / Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  Future<bool> _send(CollectionCharge c, {bool inBatch = false}) async {
    final tab = openBlankTab(); // Reserve only in the operator's direct click.
    if ((!inBatch && _busy) || !c.canContact(DateTime.now())) {
      tab?.close();
      return false;
    }
    if (!inBatch) setState(() => _busy = true);
    final message = c.message(DateTime.now());
    final event = _service.newEventId();
    try {
      if (c.phone.trim().isEmpty) {
        tab?.close();
        throw StateError('Paciente sem telefone cadastrado.');
      }
      // Validate latest financial/phone/scope before opening the external channel.
      await _service.validateBeforeSend(c);
      if (!mounted || !_alive) {
        tab?.close();
        return false;
      }
      final opened = await openWhatsAppSafe(
        context,
        tab,
        phone: collectionPhone(c.phone),
        message: message,
      );
      if (!opened || !mounted || !_alive) return false;
      final sent = await _confirm(
        'Confirmação de envio',
        'Você enviou a mensagem de cobrança para ${c.patientName} no WhatsApp?\n\nConfirmar registra o texto no prontuário e marca o contato como cobrado. Não registra pagamento. Em pacote ainda não apurado, fixa o valor rateado mostrado na prévia e preserva o valor original para histórico.',
        action: 'SIM, confirmar envio',
      );
      if (sent != true || !mounted || !_alive) return false;
      while (mounted && _alive) {
        try {
          await _service.confirmSent(c, message, event);
          if (mounted && _alive) {
            toast(context, 'Contato confirmado. Pagamento continua em aberto.');
          }
          return true;
        } catch (_) {
          if (!mounted || !_alive) return false;
          final retry = await _confirm(
            'Confirmação não registrada',
            'A cobrança pode ter mudado ou a conexão falhou. Tentar registrar novamente? O mesmo identificador será usado para evitar duplicação.',
            action: 'Tentar novamente',
          );
          if (retry != true) return false;
        }
      }
      return false;
    } catch (_) {
      try {
        tab?.close();
      } catch (_) {}
      if (mounted && _alive) {
        toast(
          context,
          'Não foi possível preparar o envio. Confira telefone, unidade e atualização da fila.',
        );
      }
      return false;
    } finally {
      if (!inBatch && _alive) setState(() => _busy = false);
    }
  }

  Future<void> _batch(List<CollectionCharge> rows) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      for (var i = 0; i < rows.length; i++) {
        if (!mounted || !_alive) return;
        final c = rows[i];
        Future<bool>? sending;
        final choice = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('Lote pendente · ${i + 1}/${rows.length}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.patientName} · ${c.clinic.name}\n${reportMoney(c.amount)}',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(c.message(DateTime.now())),
                  const SizedBox(height: 12),
                  const Text(
                    'Envio manual. Revise no WhatsApp e confirme depois se enviou. Não há disparo automático ou SMS.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'stop'),
                child: const Text('Encerrar lote'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                child: const Text('Pular'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx, 'send');
                  sending = _send(
                    c,
                    inBatch: true,
                  ); // Opens the reserved tab in this click.
                },
                child: const Text('Abrir WhatsApp'),
              ),
            ],
          ),
        );
        if (choice == 'stop' || choice == null) break;
        if (sending != null) await sending;
      }
    } finally {
      if (mounted && _alive) setState(() => _busy = false);
    }
  }

  Future<void> _reschedule(CollectionCharge c) async {
    if (_busy) return;
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 2)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
    );
    if (day == null || !mounted || !_alive) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted || !_alive) return;
    final when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final yes = await _confirm(
      'Reagendar lembrete',
      'O lembrete ficará adiado na fila até ${formatDateFull(when)} às ${time.format(context)}. O envio continuará manual; não será criado disparo automático.',
    );
    if (yes != true || !mounted || !_alive) return;
    setState(() => _busy = true);
    try {
      await _service.reschedule(c, when);
      if (mounted && _alive) {
        toast(context, 'Lembrete adiado. Envio permanece manual.');
      }
    } catch (_) {
      if (mounted && _alive) {
        toast(
          context,
          'Não foi possível reagendar. Atualize a fila e confira a data.',
        );
      }
    } finally {
      if (mounted && _alive) setState(() => _busy = false);
    }
  }

  Future<void> _receive(CollectionCharge c) async {
    if (_busy || !mounted || !_alive || c.issue != null || c.amount <= 0) {
      return;
    }
    String? selected = c.documents.length == 1 ? c.documents.single.id : null;
    double value(String id) {
      final doc = c.documents.firstWhere((d) => d.id == id);
      if (c.bill != null) return collectionQuoteShare(c, doc.data);
      return parseBRL(doc.data['amount']) - parseBRL(doc.data['paidAmount']);
    }

    selected ??= await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escolha o lançamento do pacote'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in c.documents)
                  ListTile(
                    title: Text('${d.data['title'] ?? 'Lançamento'}'),
                    subtitle: Text(reportMoney(value(d.id))),
                    enabled: value(d.id) > 0,
                    onTap: () => Navigator.pop(ctx, d.id),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted || !_alive) return;
    final amount = value(selected);
    if (c.bill != null) {
      final confirmed = await _confirm(
        'Conferir apuração do pacote',
        '${c.patientName}\nValor cadastrado: ${reportMoney(c.documents.fold<double>(0, (sum, d) => sum + parseBRL(d.data['amount'])))}\nValor apurado no mês: ${reportMoney(c.amount)}. ${c.bill!.describe()}.\n\n'
            'Antes de abrir o recebimento, o valor rateado será fixado nos lançamentos do pacote, preservando os valores originais no histórico. Não registra pagamento. A baixa será confirmada no formulário seguinte.',
      );
      if (confirmed != true || !mounted || !_alive) return;
      setState(() => _busy = true);
      try {
        await _service.preparePayment(c);
      } catch (_) {
        if (mounted && _alive) {
          toast(
            context,
            'A cobrança mudou ou a apuração falhou. Atualize a fila.',
          );
        }
        return;
      } finally {
        if (mounted && _alive) setState(() => _busy = false);
      }
    }
    if (!mounted || !_alive) return;
    _patient(c, receive: true, receiveId: selected, receiveAmount: amount);
  }

  void _patient(
    CollectionCharge c, {
    bool receive = false,
    String? receiveId,
    double? receiveAmount,
  }) {
    if (_busy || !mounted || !_alive) return;
    final nav = Navigator.of(context);
    // Existing payment UI depends on the shell clinic. Switch explicitly to the debtor's authorized unit.
    SessionManager().setClinic(c.clinic.id, c.clinic.name, c.clinic.type);
    if (receive) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Receber · ${c.patientName}')),
            body: PatientFinancialTab(
              patientId: c.patientId,
              initialReceiveId:
                  receiveId ??
                  (c.documents.length == 1 ? c.documents.single.id : null),
              initialReceiveAmount:
                  receiveAmount ?? (c.documents.length == 1 ? c.amount : null),
              expectedClinicId: c.clinic.id,
            ),
          ),
        ),
      );
    } else {
      nav.push(
        openPatient(
          c.patientId,
          c.patientName,
          section: PatientSection.payments,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CollectionClinic>>(
    future: _clinics,
    builder: (context, directory) {
      final clinics = directory.data ?? [];
      return StreamBuilder<CollectionQueue>(
        key: ValueKey('collections-${collectionPeriod(_month)}-$_user'),
        stream: _stream,
        builder: (context, snap) {
          final loading =
              directory.connectionState == ConnectionState.waiting ||
              (!snap.hasData && !snap.hasError && !directory.hasError);
          final error = directory.hasError || snap.hasError
              ? 'Não foi possível carregar as cobranças das unidades autorizadas. Tente novamente.'
              : !loading && clinics.isEmpty
              ? 'Nenhuma unidade autorizada disponível.'
              : null;
          final queue = loading || error != null
              ? CollectionQueue(clinics: clinics, charges: [])
              : snap.data!;
          return ClinicalCollectionsView(
            month: _month,
            queue: queue,
            loading: loading,
            error: error,
            busy: _busy,
            onMonth: (i) => _changeMonth(i, clinics),
            onRetry: _retry,
            onCopy: _copy,
            onSend: _send,
            onBatch: _batch,
            onReceive: _receive,
            onPatient: _patient,
            onReschedule: _reschedule,
            onExport: (rows, id) =>
                downloadCollectionsCsv(_month, rows, queue.only(id)),
          );
        },
      );
    },
  );
}
