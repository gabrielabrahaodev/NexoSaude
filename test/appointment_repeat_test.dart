import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/appointment_service.dart';

void main() {
  group('repeatNextWeek', () {
    test('soma 7 dias mantendo dia da semana e horário', () {
      // 29/09/2026 = segunda 09:30 -> 06/10 segunda 09:30
      final out = AppointmentService.repeatNextWeek(
          DateTime(2026, 9, 29, 9, 30));
      expect(out, DateTime(2026, 10, 6, 9, 30));
      expect(out.weekday, DateTime(2026, 9, 29).weekday);
    });
  });
}
