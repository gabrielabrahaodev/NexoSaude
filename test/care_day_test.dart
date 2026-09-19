import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/care_day.dart';

void main() {
  group('todayBounds', () {
    test('cobre o dia cheio [00:00, dia seguinte 00:00)', () {
      final ref = DateTime(2026, 9, 19, 15, 30);
      final b = todayBounds(ref);
      expect(b.start, DateTime(2026, 9, 19));
      expect(b.end, DateTime(2026, 9, 20));
    });
  });

  group('attendanceTemplates', () {
    test('psicologia tem modelos de sessao', () {
      final t = attendanceTemplates('psychology');
      expect(t.length, greaterThanOrEqualTo(4));
      expect(t.any((s) => s.toLowerCase().contains('sess')), isTrue);
    });

    test('odonto e demais tem modelos de procedimento', () {
      for (final type in ['dental', 'odonto', null, '']) {
        final t = attendanceTemplates(type);
        expect(t.length, greaterThanOrEqualTo(4));
      }
    });
  });

  group('nextSessionText', () {
    test('traz nome e data no tom do app', () {
      final msg =
          nextSessionText(patientName: 'Gabriel', date: DateTime(2026, 9, 20, 9, 0));
      expect(msg.contains('Gabriel'), isTrue);
      expect(msg.contains('20/09'), isTrue);
      expect(msg.contains('09:00'), isTrue);
    });
  });
}
