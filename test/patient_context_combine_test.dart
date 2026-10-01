import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/utils/display.dart';
import 'package:odonto_controle/widgets/patient_smart_context_card.dart';

void main() {
  final now = DateTime(2026, 9, 30, 19, 0);

  test('combina clinico + anamnese + 1 vencida', () {
    final ctx = combinePatientContext(
      now: now,
      latestClinical: {
        'procedureName': 'Pacote Psicologia - Sessão',
        'date': DateTime(2026, 9, 29, 10, 0),
      },
      anamnesis: {
        'hasAllergies': true,
        'allergiesDesc': 'Dipirona',
      },
      unpaid: [
        {'dueDate': DateTime(2026, 9, 24), 'amount': 150.0},
        {'dueDate': DateTime(2026, 10, 5), 'amount': 200.0},
      ],
    );

    expect(ctx.isEmpty, isFalse);
    expect(ctx.summary, contains('ontem'));
    expect(ctx.summary, contains('Pacote Psicologia - Sessão'));
    expect(ctx.summary, contains('1 pendência(s) vencida(s)'));
    expect(ctx.summary, contains(formatBRL(150.0)));
    expect(ctx.alerts, ['Alérgico(a): Dipirona']);
  });

  test('sem nada, resumo diz sem historico (comportamento mantido)', () {
    final ctx = combinePatientContext(now: now);
    expect(ctx.isEmpty, isFalse);
    expect(ctx.summary, contains('ainda não possui histórico'));
    expect(ctx.alerts, isEmpty);
  });

  test('vencimento de hoje nao conta como vencido', () {
    final ctx = combinePatientContext(
      now: now,
      unpaid: [
        {'dueDate': DateTime(2026, 9, 30, 10, 0), 'amount': 100.0},
      ],
    );
    expect(ctx.summary, isNot(contains('vencida')));
  });
}
