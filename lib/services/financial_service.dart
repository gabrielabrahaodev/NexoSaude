import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_model.dart';

class FinancialService {
  // --- ESSA LINHA É CRÍTICA PARA FUNCIONAR ---
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Busca lançamentos por paciente
  Stream<List<FinancialModel>> getByPatientId(String patientId) {
    return _db
        .collection('financial')
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinancialModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Estornar pagamento
  Future<void> voidPayment(String id) async {
    await _db.collection('financial').doc(id).update({
      'status': 'Pendente',
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
  }) async {
    final batch = _db.batch();
    final financialRef = _db.collection('financial');

    // Se o valor pago cobrir tudo, fecha o original
    bool isTotalPayment = payValue >= (originalTransaction.amount - originalTransaction.paidAmount);

    if (isTotalPayment && installments == 1) {
       // Pagamento à vista: Atualiza o original
       batch.update(financialRef.doc(originalTransaction.id), {
        'isPaid': isPaid ?? true,
        'status': status ?? 'Pago',
        'paymentDate': paymentDate ?? DateTime.now(),
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
      // Parcelado: Atualiza original e cria novos
      batch.update(financialRef.doc(originalTransaction.id), {
        'isPaid': isPaid ?? true,
        'status': status != null ? '$status (Renegociado/Parcelado)' : 'Pago (Renegociado/Parcelado)',
        'paymentDate': paymentDate ?? DateTime.now(),
        'paymentMethod': method,
        'paidAmount': payValue,
      });

      double installmentValue = payValue / installments;
      
      // Ajuste de centavos no Bruto
      double totalCalculated = double.parse(installmentValue.toStringAsFixed(2)) * installments;
      double difference = payValue - totalCalculated;

      for (int i = 1; i <= installments; i++) {
        double finalValue = double.parse(installmentValue.toStringAsFixed(2));
        if (i == 1) finalValue += difference;

        // Recupera valores calculados
        double finalTax = taxValPerInstallment ?? 0.0;
        double finalNet = netValPerInstallment ?? finalValue;

        // Ajuste de centavos no Líquido
        if (netValPerInstallment != null && installments > 1) {
             double totalNetCalc = double.parse(netValPerInstallment.toStringAsFixed(2)) * installments;
             double totalNetReal = payValue - ((taxValPerInstallment ?? 0) * installments);
             double diffNet = totalNetReal - totalNetCalc;
             if (i == 1) finalNet += diffNet;
        }

        final newDocRef = financialRef.doc();
        
        batch.set(newDocRef, {
          'clinicId': originalTransaction.clinicId,
          'patientId': originalTransaction.patientId,
          'patientName': originalTransaction.patientName,
          'title': originalTransaction.title,
          'description': "${originalTransaction.title} ($i/$installments) - $method",
          'date': DateTime.now(),
          'dueDate': DateTime.now().add(Duration(days: 30 * i)),
          'paymentDate': paymentDate ?? DateTime.now(),
          'value': finalValue, 
          'amount': finalValue,
          'isPaid': isPaid ?? true,
          'status': status ?? 'Pago',
          'type': 'income',
          'paymentMethod': method,
          'installmentNumber': "$i/$installments",
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
  }
}