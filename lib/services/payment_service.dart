import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/financial_model.dart';

class PaymentService {
  // CORREÇÃO: Definindo _db para uso geral (acesso a 'financial' e 'expenses')
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Mantemos _collection para uso nos métodos antigos que já dependiam dele
  final CollectionReference _collection = FirebaseFirestore.instance.collection('financial');

  // Método Inteligente de Recebimento
  Future<void> receivePayment({
    required FinancialModel originalDebt,
    required double amountReceived,
    required String paymentMethod,
    required int installments,
    required String? professionalId, // ID do dentista para comissão
    DateTime? firstDueDate, // Para caso de parcelamento
  }) async {
    WriteBatch batch = _db.batch(); // Usando _db aqui também é mais limpo
    DocumentReference originalRef = _collection.doc(originalDebt.id);

    // 1. Lógica de Pagamento Parcial (Se pagou menos que o total e é à vista)
    if (amountReceived < originalDebt.amount && installments == 1) {
      // Atualiza o original para o valor pago e marca como PAGO
      batch.update(originalRef, {
        'amount': amountReceived,
        'isPaid': true,
        'status': 'pago',
        'paymentMethod': paymentMethod,
        'paidDate': Timestamp.now(), // Data real do recebimento
        'professionalId': professionalId,
      });

      // Cria um NOVO lançamento com o restante (PENDENTE)
      DocumentReference remainingRef = _collection.doc();
      double remainingVal = originalDebt.amount - amountReceived;
      
      batch.set(remainingRef, {
        ...originalDebt.toMap(),
        'id': remainingRef.id,
        'title': "${originalDebt.title} (Restante)",
        'amount': remainingVal,
        'isPaid': false,
        'status': 'pendente',
        'date': Timestamp.fromDate(originalDebt.date), // Mantém data original
      });
    }
    // 2. Lógica de Parcelamento (Cartão de Crédito - "A Máquininha")
    else if (installments > 1) {
      double installmentValue = amountReceived / installments;
      DateTime currentDate = firstDueDate ?? DateTime.now();

      // Vamos "Explodir" o lançamento original em N lançamentos
      // O original vira a parcela 1
      batch.update(originalRef, {
        'title': "${originalDebt.title} (1/$installments)",
        'amount': installmentValue,
        'isPaid': true,
        'status': 'pago', // Para o paciente está pago
        'paymentMethod': paymentMethod,
        'installmentNumber': "1/$installments",
        'date': Timestamp.fromDate(currentDate), // Data da compensação financeira
        'professionalId': professionalId,
      });

      // Cria as outras N-1 parcelas
      for (int i = 2; i <= installments; i++) {
        // Regra simples: D+30 para cada parcela
        currentDate = currentDate.add(const Duration(days: 30));
        
        DocumentReference newRef = _collection.doc();
        batch.set(newRef, {
          ...originalDebt.toMap(),
          'id': newRef.id,
          'title': "${originalDebt.title} ($i/$installments)",
          'amount': installmentValue,
          'isPaid': true, // Tecnicamente o paciente pagou no cartão
          'status': 'pago',
          'paymentMethod': paymentMethod,
          'installmentNumber': "$i/$installments",
          'date': Timestamp.fromDate(currentDate), // Data futura de entrada no caixa
          'professionalId': professionalId,
        });
      }
    }
    // 3. Pagamento Total Simples (À Vista)
    else {
      batch.update(originalRef, {
        'amount': amountReceived, // Garante valor exato
        'isPaid': true,
        'status': 'pago',
        'paymentMethod': paymentMethod,
        'paidDate': Timestamp.now(),
        'professionalId': professionalId,
      });
    }

    await batch.commit();
  }

  /// Realiza o estorno de uma transação (Receita ou Despesa)
  Future<void> reverseTransaction(String id, bool isIncome) async {
    if (isIncome) {
      // ESTORNO DE RECEITA (Conta do Paciente)
      // Ao setar isPaid = false e paidAmount = 0, o sistema automaticamente
      // entende que o valor "voltou" para o saldo devedor (parcela pai restante).
      await _db.collection('financial').doc(id).update({
        'isPaid': false,
        'paidAmount': 0.0, // Zera o valor pago, voltando a dívida original
        'paymentDate': FieldValue.delete(), // Remove data de pagamento
        'paymentMethod': FieldValue.delete(), // Remove forma de pagamento
        'status': 'pendente'
      });
    } else {
      // ESTORNO DE DESPESA (Conta a Pagar)
      await _db.collection('expenses').doc(id).update({
        'status': 'pendente',
        'paidDate': FieldValue.delete(),
      });
    }
  }
}