import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/appointment_service.dart';

void main() {
  group('isSlotFree', () {
    test('horário fora da lista de ocupados está livre', () {
      expect(AppointmentService.isSlotFree('09:30', ['10:00', '11:00']),
          isTrue);
    });

    test('horário na lista de ocupados não está livre', () {
      expect(AppointmentService.isSlotFree('09:30', ['09:30', '10:00']),
          isFalse);
    });

    test('grade vazia deixa tudo livre', () {
      expect(AppointmentService.isSlotFree('09:30', []), isTrue);
    });
  });
}
