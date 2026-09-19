import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço de estorno do livro-caixa.
/// (O antigo `receivePayment`/parcelamento-"explosão" foi removido: morto,
/// sem chamadores — o recebimento vive em `FinancialService.processPayment`.)
class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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