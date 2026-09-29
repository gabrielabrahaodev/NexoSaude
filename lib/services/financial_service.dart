import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_model.dart';
import 'portal_mirror.dart';
import 'session_manager.dart';

/// Parcela calculada: bruto, taxa e líquido (2 casas, ajustes na 1ª).
class InstallmentSlice {
  final double value;
  final double tax;
  final double net;

  const InstallmentSlice({
    required this.value,
    required this.tax,
    required this.net,
  });
}

class FinancialService {
  // --- ESSA LINHA É CRÍTICA PARA FUNCIONAR ---
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Delta do espelho após mutação de lançamento (1 leitura + patch).
  Future<void> _syncDebtOfCharge(String id) async {
    try {
      final d = await _db.collection('financial').doc(id).get();
      final m = d.data();
      if (m == null) return;
      final pid = '${m['patientId'] ?? ''}';
      if (pid.isEmpty) return;
      await PortalMirrorSync.upsertDebt(patientId: pid, debt: {
        'id': id,
        'title': '${m['title'] ?? 'Lançamento'}',
        'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
        'paidAmount': (m['paidAmount'] as num?)?.toDouble() ?? 0.0,
        'dueDate': (m['dueDate'] as Timestamp?)?.toDate(),
        'status': '${m['status'] ?? ''}',
      });
    } catch (_) {}
  }

  /// Parcela calculada (bruto, taxa e líquido já com ajustes de centavos).
  /// Extraído puro a partir do loop do `processPayment` — mesma matemática.
  static List<InstallmentSlice> computeInstallments({
    required double payValue,
    required int installments,
    double? taxPerInstallment,
    double? netPerInstallment,
  }) {
    final installmentValue = payValue / installments;

    // Ajuste de centavos no Bruto (diferença vai para a 1ª)
    final totalCalculated =
        double.parse(installmentValue.toStringAsFixed(2)) * installments;
    final difference = payValue - totalCalculated;

    final out = <InstallmentSlice>[];
    for (int i = 1; i <= installments; i++) {
      double finalValue = double.parse(installmentValue.toStringAsFixed(2));
      if (i == 1) finalValue += difference;

      double finalTax = taxPerInstallment ?? 0.0;
      double finalNet = netPerInstallment ?? finalValue;

      // Ajuste de centavos no Líquido (diferença vai para a 1ª)
      if (netPerInstallment != null && installments > 1) {
        final totalNetCalc =
            double.parse(netPerInstallment.toStringAsFixed(2)) * installments;
        final totalNetReal =
            payValue - ((taxPerInstallment ?? 0) * installments);
        final diffNet = totalNetReal - totalNetCalc;
        if (i == 1) finalNet += diffNet;
      }

      out.add(InstallmentSlice(
        value: finalValue,
        tax: finalTax,
        net: finalNet,
      ));
    }
    return out;
  }

  /// Soma N meses preservando o dia (clamp p/ o último dia do mês).
  /// Puro e testado — base dos vencimentos do parcelamento.
  static DateTime addMonths(DateTime from, int months) {
    final total = (from.month - 1) + months;
    final year = from.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = from.day > lastDay ? lastDay : from.day;
    return DateTime(
        year, month, day, from.hour, from.minute, from.second);
  }

  /// Como um recebimento deve ser gravado conforme o método.
  /// Métodos imediatos (Dinheiro/Pix/...) = pago na hora (`pago`).
  /// Cartão mantém o fluxo próprio de recebível (`paid`).
  /// (Antes, não-cartão gravava `pending`/`isPaid:false` e sumia dos
  /// relatórios, que leem o campo cru — a aba parecia certa porque o
  /// getter `isPaid` deriva de `paidAmount`.)
  static ({String status, bool isPaid}) recordingFor(String method) {
    if (method.contains('Cartão')) return (status: 'paid', isPaid: true);
    return (status: 'pago', isPaid: true);
  }

  // Busca lançamentos por paciente (filtrado pela clínica da sessão)
  Stream<List<FinancialModel>> getByPatientId(String patientId) {
    return SessionManager()
        .applyFilter(
            _db.collection('financial').where('patientId', isEqualTo: patientId))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinancialModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Estornar pagamento (volta a pendente, mantém histórico)
  Future<void> voidPayment(String id) async {
    await _db.collection('financial').doc(id).update({
      'status': 'pendente',
      'isPaid': false,
      'paidAmount': 0.0,
      'paymentDate': null,
      'paymentMethod': null,
      'feePercentage': 0.0,
      'feeAmount': 0.0,
      'taxVal': 0.0,
      'valorLiquido': 0.0,
      'netAmount': 0.0,
    });
    await _syncDebtOfCharge(id);
  }

  /// Cancela uma cobrança/lançamento (soft-delete com trilha).
  /// Some dos relatórios/cobrança/risco (todos excluem `cancelado`)
  /// sem apagar o histórico (fiscal). Para corrigir valor, usar
  /// estorno + relançamento em vez disso.
  Future<void> cancelCharge(String id) async {
    await _db.collection('financial').doc(id).update({
      'status': 'cancelado',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    await _syncDebtOfCharge(id);
  }

  /// Cancela a família inteira num batch só (ou tudo ou nada):
  /// vinculados excluídos + status `cancelado` + espelho do portal.
  Future<void> cancelFamily(List<String> ids) async {
    final batch = _db.batch();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk =
          ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final exps = await _db
          .collection('expenses')
          .where('relatedFinancialId', whereIn: chunk)
          .get();
      final labs = await _db
          .collection('lab_orders')
          .where('relatedFinancialId', whereIn: chunk)
          .get();
      for (var doc in [...exps.docs, ...labs.docs]) {
        batch.delete(doc.reference);
      }
    }
    for (final fid in ids) {
      batch.update(_db.collection('financial').doc(fid), {
        'status': 'cancelado',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    for (final fid in ids) {
      try {
        await _syncDebtOfCharge(fid);
      } catch (_) {}
    }
  }

  /// Monta os dados da cobrança recriada a partir de um doc cancelado.
  /// Mantém termos e vínculos (plano, orçamento, parcela, vencimento
  /// original); zera quitação e taxas (o recebimento recalcula tudo).
  /// [amount]/[dueDate] opcionais corrigem o valor no mesmo passo.
  /// Puro e testado — o `add` + `date` de lançamento ficam no caller.
  static Map<String, dynamic> recreatedData(
    Map<String, dynamic> original, {
    double? amount,
    DateTime? dueDate,
  }) {
    final data = Map<String, dynamic>.from(original);
    data['status'] = 'pendente';
    data['paidAmount'] = 0.0;
    data['paymentDate'] = null;
    data['paymentMethod'] = '';
    data['feePercentage'] = 0.0;
    data['feeAmount'] = 0.0;
    data['taxVal'] = 0.0;
    data['valorLiquido'] = 0.0;
    data['netAmount'] = 0.0;
    data['payerName'] = '';
    data['payerCpf'] = '';
    data.remove('cancelledAt');
    if (amount != null) data['amount'] = amount;
    if (dueDate != null) data['dueDate'] = Timestamp.fromDate(dueDate);
    return data;
  }

  /// Recria uma cobrança cancelada como pendente nova (clone-zerado).
  /// Retorna o id do novo doc. Vale p/ qualquer origem (pendente ou paga).
  Future<String> recreateCharge(
    String id, {
    double? amount,
    DateTime? dueDate,
  }) async {
    final doc = await _db.collection('financial').doc(id).get();
    final original = doc.data();
    if (original == null) throw Exception('Lançamento não encontrado.');
    final data = recreatedData(original, amount: amount, dueDate: dueDate);
    data['date'] = FieldValue.serverTimestamp();
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _db.collection('financial').add(data);
    final pid = '${original['patientId'] ?? ''}';
    if (pid.isNotEmpty) {
      await PortalMirrorSync.upsertDebt(patientId: pid, debt: {
        'id': ref.id,
        'title': '${data['title'] ?? 'Lançamento'}',
        'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
        'paidAmount': 0.0,
        'dueDate': (data['dueDate'] as Timestamp?)?.toDate(),
        'status': 'pendente',
      });
    }
    return ref.id;
  }

  /// Edição simples de pendente (valor/vencimento). Não mexe em quitação,
  /// parcelas-irmãs nem vínculos — para correção profunda, usar
  /// estorno + relançamento ou cancelar + recriar.
  Future<void> editPendingCharge(
    String id, {
    double? amount,
    DateTime? dueDate,
  }) async {
    final data = <String, dynamic>{};
    if (amount != null) data['amount'] = amount;
    if (dueDate != null) data['dueDate'] = Timestamp.fromDate(dueDate);
    if (data.isEmpty) return;
    await _db.collection('financial').doc(id).update(data);
    await _syncDebtOfCharge(id);
  }

  // --- PROCESSA E SALVA TUDO DE UMA VEZ ---
  Future<void> processPayment({
    required FinancialModel originalTransaction,
    required double payValue,
    required String method,
    required int installments,
    required String payerName,
    required String payerCpf,
    String? dentistId,
    String? dentistName,
    // CAMPOS DE TAXA
    double? feePercentage,
    double? taxValPerInstallment,
    double? netValPerInstallment,
    // CAMPOS DA WAR ROOM (Cartão de Crédito)
    String? status,
    bool? isPaid,
    DateTime? paymentDate,
    // Vencimentos por parcela (default: addMonths a partir de hoje).
    List<DateTime>? dueDates,
  }) async {
    final batch = _db.batch();
    final financialRef = _db.collection('financial');

    // Se o valor pago cobrir tudo, fecha o original
    bool isTotalPayment = payValue >= (originalTransaction.amount - originalTransaction.paidAmount);

    if (isTotalPayment && installments == 1) {
       // Pagamento à vista: Atualiza o original
       batch.update(financialRef.doc(originalTransaction.id), {
        'isPaid': isPaid ?? true,
        'status': status ?? 'pago',
        'paymentDate': paymentDate ?? FieldValue.serverTimestamp(),
        'paymentMethod': method,
        'paidAmount': payValue,
        'payerName': payerName,
        'payerCpf': payerCpf,
        'dentistId': dentistId,
        'dentistName': dentistName,
        // Grava taxas
        'feePercentage': feePercentage ?? 0.0,
        'taxVal': taxValPerInstallment ?? 0.0,
        'valorLiquido': netValPerInstallment ?? payValue,
        'netAmount': netValPerInstallment ?? payValue,
      });
    } else {
      // Parcelado ou parcial: original vira terminal (nunca delete —
      // histórico fiscal) ou segue pendente com o saldo aberto.
      // Parcial (valor < saldo) não explode parcelas: quita sem parcelar.
      final sliced = isTotalPayment ? installments : 1;
      batch.update(financialRef.doc(originalTransaction.id), {
        'isPaid': isTotalPayment ? (isPaid ?? true) : false,
        'status': isTotalPayment
            ? 'substituido (parcelado)'
            : 'pendente',
        'paymentDate': paymentDate ?? FieldValue.serverTimestamp(),
        'paymentMethod': method,
        'paidAmount': payValue,
      });

      final slices = FinancialService.computeInstallments(
        payValue: payValue,
        installments: sliced,
        taxPerInstallment: taxValPerInstallment,
        netPerInstallment: netValPerInstallment,
      );

      final baseDay = DateTime.now();
      for (int i = 1; i <= sliced; i++) {
        final slice = slices[i - 1];
        final double finalValue = slice.value;
        final double finalTax = slice.tax;
        final double finalNet = slice.net;
        final due = (dueDates != null && dueDates.length >= i)
            ? dueDates[i - 1]
            : FinancialService.addMonths(baseDay, i);

        final newDocRef = financialRef.doc();

        batch.set(newDocRef, {
          'clinicId': originalTransaction.clinicId,
          'patientId': originalTransaction.patientId,
          'patientName': originalTransaction.patientName,
          'title': originalTransaction.title,
          'description': sliced > 1
              ? "${originalTransaction.title} ($i/$sliced) - $method"
              : "${originalTransaction.title} (parcial) - $method",
          'date': FieldValue.serverTimestamp(),
          'dueDate': due,
          'paymentDate': paymentDate ?? FieldValue.serverTimestamp(),
          'value': finalValue,
          'amount': finalValue,
          'paidAmount': finalValue, // parcela nasce quitada (getter isPaid fecha)
          'isPaid': isPaid ?? true,
          'status': status ?? 'pago',
          'type': 'income',
          'paymentMethod': method,
          'installmentNumber': sliced > 1 ? "$i/$sliced" : null,
          'parentId': originalTransaction.id, // família p/ cancelamento em lote
          'dentistId': dentistId,
          'dentistName': dentistName,
          'createdAt': FieldValue.serverTimestamp(),

          // GRAVAÇÃO DOS CAMPOS
          'feePercentage': feePercentage ?? 0.0,
          'taxVal': double.parse(finalTax.toStringAsFixed(2)),
          'valorLiquido': double.parse(finalNet.toStringAsFixed(2)),
          'netAmount': double.parse(finalNet.toStringAsFixed(2)),
        });
      }
    }

    await batch.commit();
    await _syncDebtOfCharge(originalTransaction.id);
  }
}