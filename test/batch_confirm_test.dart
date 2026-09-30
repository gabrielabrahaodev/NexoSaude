import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/services/care_day.dart';

AppointmentModel _appt(String id, String status) => AppointmentModel(
      id: id,
      patientId: 'p1',
      patientName: 'Gabriel',
      date: DateTime(2026, 9, 29, 9, 30),
      status: status,
      procedure: 'Sessão',
      clinicId: 'c1',
    );

void main() {
  group('needsConfirmation', () {
    test('só Aguardando Confirmação precisa', () {
      expect(needsConfirmation(_appt('a', 'Aguardando Confirmação')), isTrue);
      expect(needsConfirmation(_appt('b', 'aguardando confirmação')), isTrue);
    });

    test('confirmado, finalizado, cancelado e remarcar ficam de fora', () {
      expect(needsConfirmation(_appt('b', 'Confirmado')), isFalse);
      expect(needsConfirmation(_appt('c', 'Finalizado')), isFalse);
      expect(needsConfirmation(_appt('d', 'Cancelado')), isFalse);
      expect(needsConfirmation(_appt('e', 'remarcar')), isFalse);
    });
  });
}
