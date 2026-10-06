import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/oracle_report_service.dart';

TransactionItem tx(String id,
        {required bool isPaid, required DateTime due}) =>
    TransactionItem(
      id: id,
      title: id,
      amount: 100,
      date: due,
      dueDate: due,
      isIncome: true,
      isPaid: isPaid,
      category: 'Receita',
    );

void main() {
  final now = DateTime(2026, 10, 6, 18, 0);
  final items = [
    tx('pago', isPaid: true, due: DateTime(2026, 10, 1)),
    tx('futuro', isPaid: false, due: DateTime(2026, 10, 20)),
    tx('hoje', isPaid: false, due: DateTime(2026, 10, 6, 9, 0)),
    tx('vencido', isPaid: false, due: DateTime(2026, 9, 24)),
  ];

  test('todos mantém tudo', () {
    expect(flowFilter(items, FlowFilter.todos, now).length, 4);
  });

  test('recebido só pagos', () {
    final out = flowFilter(items, FlowFilter.recebido, now);
    expect(out.map((t) => t.id), ['pago']);
  });

  test('a receber: pendentes de hoje em diante', () {
    final out = flowFilter(items, FlowFilter.aReceber, now);
    expect(out.map((t) => t.id), ['futuro', 'hoje']);
  });

  test('inadimplente: pendente vencido antes de hoje', () {
    final out = flowFilter(items, FlowFilter.inadimplente, now);
    expect(out.map((t) => t.id), ['vencido']);
  });
}
