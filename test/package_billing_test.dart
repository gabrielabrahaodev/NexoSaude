import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/services/package_billing.dart';

AppointmentModel _session({
  String status = 'Finalizado',
  String? attendance,
  bool cert = false,
}) {
  return AppointmentModel(
    id: 'a',
    patientId: 'p',
    patientName: 'Teste',
    date: DateTime(2026, 9, 7, 9),
    status: status,
    procedure: 'Pacote Psicologia - Sessão',
    clinicId: 'c',
    attendanceStatus: attendance,
    hasMedicalCertificate: cert,
  );
}

List<AppointmentModel> _five({
  int missedWithCert = 0,
  int missedWithout = 0,
  int pending = 0,
  int cancelled = 0,
}) {
  final list = <AppointmentModel>[];
  final attended =
      5 - missedWithCert - missedWithout - pending - cancelled;
  for (var i = 0; i < attended; i++) {
    list.add(_session(attendance: 'Attended'));
  }
  for (var i = 0; i < missedWithCert; i++) {
    list.add(_session(attendance: 'Missed', cert: true));
  }
  for (var i = 0; i < missedWithout; i++) {
    list.add(_session(attendance: 'Missed'));
  }
  for (var i = 0; i < pending; i++) {
    list.add(_session(status: 'Aguardando Confirmação'));
  }
  for (var i = 0; i < cancelled; i++) {
    list.add(_session(status: 'Cancelado', attendance: 'Missed'));
  }
  return list;
}

void main() {
  group('PackageBilling.compute', () {
    test('5 atendidas de 5 cobra cheio', () {
      final bill = PackageBilling.compute(
        packageAmount: 500,
        discount: 0,
        sessions: _five(),
      );
      expect(bill.amountDue, 500);
      expect(bill.fullAmount, 500);
      expect(bill.billable, 5);
      expect(bill.isPartial, isFalse);
    });

    test('falta SEM atestado cobra normal', () {
      final bill = PackageBilling.compute(
        packageAmount: 500,
        discount: 0,
        sessions: _five(missedWithout: 1),
      );
      expect(bill.amountDue, 500);
      expect(bill.missedUnexcused, 1);
    });

    test('falta COM atestado abate (exemplo 5/500 -> 400)', () {
      final bill = PackageBilling.compute(
        packageAmount: 500,
        discount: 0,
        sessions: _five(missedWithCert: 1),
      );
      expect(bill.amountDue, 400);
      expect(bill.missedExcused, 1);
      expect(bill.billable, 4);
    });

    test('mês parcial cobra proporcional', () {
      final bill = PackageBilling.compute(
        packageAmount: 500,
        discount: 0,
        sessions: _five(pending: 2),
      );
      expect(bill.previstas, 5);
      expect(bill.finalized, 3);
      expect(bill.amountDue, 300);
      expect(bill.isPartial, isTrue);
    });

    test('desconto entra antes do rateio', () {
      final bill = PackageBilling.compute(
        packageAmount: 500,
        discount: 100,
        sessions: _five(missedWithCert: 1),
      );
      expect(bill.fullAmount, 400);
      expect(bill.amountDue, 320);
    });

    test('cancelada sai do cálculo', () {
      final bill = PackageBilling.compute(
        packageAmount: 500,
        discount: 0,
        sessions: _five(cancelled: 1, pending: 0).take(4).toList(),
      );
      expect(bill.previstas, 4);
      expect(bill.amountDue, 500);
    });

    test('lista vazia zera sem quebrar', () {
      final bill = PackageBilling.compute(
        packageAmount: 500,
        discount: 0,
        sessions: const [],
      );
      expect(bill.amountDue, 0);
      expect(bill.previstas, 0);
    });
  });
}
