import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/block_interval.dart';

DateTime day(int h, [int m = 0]) => DateTime(2026, 9, 22, h, m);

void main() {
  group('snap da grade (30min)', () {
    test('floor/ceil alinham no grid', () {
      expect(snapDown(day(12, 10)), day(12, 0));
      expect(snapUp(day(12, 10)), day(12, 30));
      expect(snapDown(day(12, 45)), day(12, 30));
      expect(snapUp(day(12, 45)), day(13, 0));
    });

    test('já alinhado não muda', () {
      expect(snapDown(day(12, 30)), day(12, 30));
      expect(snapUp(day(12, 30)), day(12, 30));
      expect(snapDown(day(12, 0)), day(12, 0));
      expect(snapUp(day(12, 0)), day(12, 0));
    });
  });

  group('overlap (meio-aberto)', () {
    test('parcial e contido sobrepõem', () {
      expect(overlap(day(12), day(14), day(13), day(15)), isTrue);
      expect(overlap(day(12), day(14), day(12, 30), day(13)), isTrue);
      expect(overlap(day(12), day(14), day(12), day(14)), isTrue);
    });

    test('encostou no limite NÃO é choque (consulta termina quando o bloco começa)', () {
      expect(overlap(day(12), day(14), day(14), day(15)), isFalse);
      expect(overlap(day(12), day(14), day(10), day(12)), isFalse);
    });
  });

  group('touchesOrOverlaps (p/ fusão)', () {
    test('adjacente funde junto', () {
      expect(touchesOrOverlaps(day(11, 30), day(12), day(12), day(14)), isTrue);
      expect(touchesOrOverlaps(day(12), day(14), day(13), day(15)), isTrue);
    });

    test('separado não funde', () {
      expect(touchesOrOverlaps(day(8), day(10), day(12), day(14)), isFalse);
    });
  });

  group('unionAll (fusão em um só)', () {
    test('une sobrepostos na cobertura total', () {
      final u = unionAll([
        (start: day(12), end: day(14)),
        (start: day(13), end: day(15)),
        (start: day(11, 30), end: day(12)),
      ]);
      expect(u.start, day(11, 30));
      expect(u.end, day(15));
    });

    test('único retorna ele mesmo', () {
      final u = unionAll([(start: day(12), end: day(14))]);
      expect(u.start, day(12));
      expect(u.end, day(14));
    });
  });

  group('findOverlaps (regra 1: paciente primeiro)', () {
    test('acha consultas reais no intervalo', () {
      final appts = [
        (start: day(13), end: day(13, 30)),
        (start: day(16), end: day(17)),
      ];
      final hit = findOverlaps(day(12), day(14), appts);
      expect(hit, hasLength(1));
      expect(hit.first.start, day(13));
    });

    test('consulta que termina no início do bloco não trava', () {
      final appts = [(start: day(11, 30), end: day(12))];
      expect(findOverlaps(day(12), day(14), appts), isEmpty);
    });
  });

  group('expandSlots (espelho + grade)', () {
    test('2h viram 4 slots', () {
      final slots = expandSlots(day(12), day(14));
      expect(slots, [day(12), day(12, 30), day(13), day(13, 30)]);
    });

    test('30min vira 1 slot', () {
      expect(expandSlots(day(12), day(12, 30)), [day(12)]);
    });
  });

  group('isNoOp (regra 3: idempotência)', () {
    test('mesmo intervalo existente = nada a fazer', () {
      expect(
        isNoOp(
          mergedStart: day(12),
          mergedEnd: day(14),
          overlappedCount: 1,
          existingStart: day(12),
          existingEnd: day(14),
        ),
        isTrue,
      );
    });

    test('mudou cobertura ou absorveu vizinhos = escreve', () {
      expect(
        isNoOp(
          mergedStart: day(12),
          mergedEnd: day(15),
          overlappedCount: 1,
          existingStart: day(12),
          existingEnd: day(14),
        ),
        isFalse,
      );
      expect(
        isNoOp(
          mergedStart: day(12),
          mergedEnd: day(14),
          overlappedCount: 2,
          existingStart: day(12),
          existingEnd: day(14),
        ),
        isFalse,
      );
    });
  });
}
