import '../models/appointment_model.dart';

/// Resultado do rateio de um pacote mensal por presença.
///
/// Regras (decisões do produto):
/// 1. Mês incompleto cobra parcial (só sessões finalizadas).
/// 2. Divisor = sessões previstas no mês (todas geradas, menos canceladas).
/// 3. Falta com atestado não conta como falta (abate do valor).
/// 4. Desconto de terceiro entra antes do rateio (teto = pacote − desconto).
class PackageBill {
  final int previstas;
  final int finalized;
  final int attended;
  final int missedExcused;
  final int missedUnexcused;
  final int billable;
  final double fullAmount;
  final double amountDue;
  final bool isPartial;

  const PackageBill({
    required this.previstas,
    required this.finalized,
    required this.attended,
    required this.missedExcused,
    required this.missedUnexcused,
    required this.billable,
    required this.fullAmount,
    required this.amountDue,
    required this.isPartial,
  });

  String describe() {
    final parts = <String>[
      '$finalized/$previstas sessões',
      if (missedExcused > 0)
        '$missedExcused com atestado',
    ];
    return parts.join(' • ');
  }
}

class PackageBilling {
  static double _round2(double value) =>
      (value * 100).roundToDouble() / 100;

  /// Calcula o valor devido de um pacote mensal.
  ///
  /// [packageAmount] valor cheio do pacote no mês.
  /// [discount] desconto de terceiro (entra antes do rateio).
  /// [sessions] appointments do pacote-mês (inclui pendentes).
  static PackageBill compute({
    required double packageAmount,
    required double discount,
    required List<AppointmentModel> sessions,
  }) {
    final double fullAmount =
        (packageAmount - discount) < 0 ? 0.0 : packageAmount - discount;

    final valid = sessions
        .where((s) => s.status.toLowerCase() != 'cancelado')
        .toList();
    final int previstas = valid.length;

    int attended = 0;
    int missedExcused = 0;
    int missedUnexcused = 0;

    for (final s in valid) {
      if (s.status != 'Finalizado') continue;
      if (s.attendanceStatus == 'Missed') {
        if (s.hasMedicalCertificate) {
          missedExcused++;
        } else {
          missedUnexcused++;
        }
      } else {
        attended++;
      }
    }

    final int finalized = attended + missedExcused + missedUnexcused;
    final int billable = attended + missedUnexcused;
    final double sessionValue =
        previstas > 0 ? fullAmount / previstas : 0.0;

    return PackageBill(
      previstas: previstas,
      finalized: finalized,
      attended: attended,
      missedExcused: missedExcused,
      missedUnexcused: missedUnexcused,
      billable: billable,
      fullAmount: _round2(fullAmount),
      amountDue: _round2(billable * sessionValue),
      isPartial: finalized < previstas,
    );
  }
}
