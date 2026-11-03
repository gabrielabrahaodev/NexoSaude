import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/receita_saude_report.dart';
import 'package:odonto_controle/services/oracle_report_service.dart';
import 'package:odonto_controle/utils/receita_saude_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final month = DateTime(2026, 10);
  ReceitaSaudeLine line({String id = 'a', String professional = 'p'}) =>
      ReceitaSaudeLine(
        id: id,
        patientId: 'patient',
        patientName: 'Paciente Teste',
        professionalId: professional,
        professionalName: 'Profissional Teste',
        amount: 1234.56,
        description: 'Serviço prestado',
        paymentDate: DateTime(2026, 10, 5),
        payerCpf: '529.982.247-25',
        beneficiaryCpf: '111.444.777-35',
      );
  String csv(
    List<ReceitaSaudeLine> rows, {
    String reg = 'CRO123',
    String cpf = '529.982.247-25',
    String occupation = '226',
  }) => receitaSaudeCsv(
    month: month,
    rows: rows,
    professionalCpf: cpf,
    occupation: occupation,
    registration: reg,
  );
  ReportDocument payment(String id, Map<String, dynamic> extra) =>
      ReportDocument(id, {
        'type': 'income',
        'amount': 100,
        'status': 'pago',
        'paymentDate': month,
        'patientId': 'patient',
        'dentistId': 'p',
        ...extra,
      });
  test(
    'official layout exactly 16 fields, no header/BOM, PF/receipt flags and gross value',
    () {
      final s = csv([line()]);
      final f = s.split(';');
      expect(f.length, 16);
      expect(f, [
        '05/10/2026',
        'R01.001.001',
        '226',
        '1234,56',
        '',
        'Serviço prestado',
        'PF',
        '52998224725',
        '11144477735',
        '',
        '',
        '',
        '',
        'S',
        '52998224725',
        'CRO123',
      ]);
      expect(s.startsWith('\uFEFF'), false);
    },
  );
  test('separate rows, no monthly consolidation, omitted unselected', () {
    final b = line(id: 'b')..amount = 10;
    final c = line(id: 'c')..selected = false;
    expect(csv([line(), b, c]).split('\r\n').length, 2);
  });
  test(
    'refuses missing CPFs, pending dates, mixed professional, year and invalid registration',
    () {
      expect(() => csv([line()], cpf: ''), throwsArgumentError);
      expect(() => csv([line()], occupation: '999'), throwsArgumentError);
      expect(() => csv([line()], reg: 'CRO;injected'), throwsArgumentError);
      expect(() => csv([line()], reg: 'CRO\ninjected'), throwsArgumentError);
      expect(() => csv([line()..payerCpf = '']), throwsArgumentError);
      expect(() => csv([line()..beneficiaryCpf = '']), throwsArgumentError);
      expect(() => csv([line()..paymentDate = null]), throwsArgumentError);
      expect(
        () => csv([line()..paymentDate = DateTime(2025, 10)]),
        throwsArgumentError,
      );
      expect(
        () => csv([line(), line(id: 'b', professional: 'q')]),
        throwsArgumentError,
      );
    },
  );
  test(
    'rejects >1000, zero, invalid amounts and allows single active blank registration',
    () {
      expect(
        () => csv(List.generate(1001, (i) => line(id: '$i'))),
        throwsArgumentError,
      );
      for (final amount in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        100000000000.0,
      ]) {
        expect(() => csv([line()..amount = amount]), throwsArgumentError);
      }
      expect(csv([line()], reg: '').split(';').last, '');
    },
  );
  test(
    'description sanitizes delimiters/formulas and Unicode length without extra columns',
    () {
      final row = line()
        ..description = '=TEST();\r\n"${List.filled(300, 'á').join()}';
      final s = csv([row]);
      expect(s.split(';').length, 16);
      expect(s.split(';')[5].runes.length, 255);
      expect(s.split(';')[5].startsWith("'=TEST()"), true);
      expect(s.split('\n').length, 1);
    },
  );
  test('payment date wins over credit due/anticipation dates', () {
    final rows = receitaSaudeLines(month, [
      payment('card', {
        'paymentMethod': 'Cartão de Crédito',
        'dueDate': DateTime(2027, 1),
        'paidDate': DateTime(2026, 11),
        'status': 'anticipated',
      }),
      payment('other', {'paymentDate': DateTime(2026, 9), 'paidDate': month}),
    ]);
    expect(rows.single.id, 'card');
    expect(rows.single.paymentDate, month);
  });
  test(
    'excludes pending/replaced/cancelled/expense; deduplicates query unions',
    () {
      final a = payment('ok', {});
      final rows = receitaSaudeLines(month, [
        a,
        a,
        payment('pending', {'status': 'pendente'}),
        payment('replaced', {'status': 'substituido (parcelado)'}),
        payment('cancelled', {'status': 'cancelado', 'isPaid': true}),
        payment('expense', {'type': 'expense'}),
      ]);
      expect(rows.map((r) => r.id), ['ok']);
    },
  );
  test(
    'partial anticipation split recombines original patient payment once',
    () {
      final original = payment('original', {
        'amount': 60,
        'status': 'anticipated',
      });
      final split = payment('split', {
        'amount': 40,
        'isPartialAnticipation': true,
        'originalDocId': 'original',
        'status': 'anticipated',
      });
      final rows = receitaSaudeLines(month, [split, original, split]);
      expect(rows.single.amount, 100);
      expect(rows.single.id, 'original');
    },
  );
  test(
    'does not invent payer/date/professional from patient or settlement',
    () {
      final rows = receitaSaudeLines(month, [
        payment('x', {
          'paymentDate': null,
          'paidDate': month,
          'status': 'anticipated',
          'dentistId': null,
          'dentistName': null,
        }),
      ]);
      expect(rows.single.paymentDate, isNull);
      expect(rows.single.payerCpf, isEmpty);
      expect(rows.single.professionalKey, 'unassigned');
      expect(rows.single.issues(month).length, 3);
    },
  );
  test(
    'PDF is a support report, generated with missing-data draft as well',
    () async {
      final data = ReceitaSaudeExport(
        rows: [line()..payerCpf = ''],
        professionalName: 'Profissional Teste',
        professionalCpf: '52998224725',
        registration: 'CRO123',
        occupation: '226',
        pdf: true,
      );
      final bytes = await receitaSaudePdf(month, 'Clínica Teste', data);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(1000));
    },
  );
}
