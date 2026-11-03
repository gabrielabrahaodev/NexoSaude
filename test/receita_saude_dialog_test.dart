import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/receita_saude_report.dart';
import 'package:odonto_controle/screens/reports/receita_saude_dialog.dart';
import 'package:odonto_controle/services/receita_saude_service.dart';
import 'package:odonto_controle/ui/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [390.0, 768.0, 1200.0]) {
      testWidgets('Receita Saúde $width dark=$dark: review/export/focus', (
        tester,
      ) async {
        AppColors.isDark = dark;
        addTearDown(() => AppColors.isDark = false);
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final row = ReceitaSaudeLine(
          id: 'a',
          patientId: 'patient',
          patientName: 'Paciente Teste',
          professionalId: 'p',
          professionalName: 'Profissional Teste',
          amount: 300,
          description: 'Procedimento',
          paymentDate: DateTime(2026, 10, 5),
          beneficiaryCpf: '11144477735',
        );
        final exports = <ReceitaSaudeExport>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(dark: dark),
            home: Scaffold(
              body: ReceitaSaudeDialog(
                month: DateTime(2026, 10),
                clinicName: 'Yervant',
                load: () async => ReceitaSaudeData(
                  [row],
                  {
                    'p': {'cpf': '52998224725'},
                  },
                ),
                onExport: (data) async {
                  exports.add(data);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('receita-professional')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profissional Teste').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('receita-export-csv')));
        await tester.pumpAndSettle();
        expect(exports, isEmpty);
        expect(find.textContaining('Confira o CPF'), findsOneWidget);
        final check = find.text('Pagador é o próprio beneficiário');
        await tester.ensureVisible(check);
        await tester.tap(check);
        await tester.pumpAndSettle();
        expect(row.payerCpf, row.beneficiaryCpf);
        await tester.tap(find.byKey(const ValueKey('receita-export-csv')));
        await tester.pumpAndSettle();
        expect(exports.length, 1);
        expect(exports.single.pdf, false);
        final name = find.byKey(const ValueKey('receita-professional-name'));
        await tester.ensureVisible(name);
        await tester.enterText(name, 'Nome correto');
        await tester.pump();
        expect(find.text('Nome correto'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Relatório PDF'));
        await tester.pumpAndSettle();
        expect(exports.last.pdf, true);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('load failure retries instead of exporting empty data', (
    tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceitaSaudeDialog(
            month: DateTime(2026, 10),
            clinicName: 'Clínica',
            load: () async {
              calls++;
              if (calls == 1) throw StateError('offline');
              return const ReceitaSaudeData([], {});
            },
            onExport: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum pagamento recebido'), findsOneWidget);
    expect(calls, 2);
  });
  testWidgets('export blocks double click and preserves draft on failure', (
    tester,
  ) async {
    final done = Completer<void>();
    int calls = 0;
    final row = ReceitaSaudeLine(
      id: 'x',
      patientId: 'patient',
      patientName: 'Teste',
      professionalId: 'p',
      professionalName: 'Dentista',
      amount: 10,
      description: 'Serviço',
      paymentDate: DateTime(2026, 10, 1),
      payerCpf: '52998224725',
      beneficiaryCpf: '11144477735',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceitaSaudeDialog(
            month: DateTime(2026, 10),
            clinicName: 'Clínica',
            load: () async => ReceitaSaudeData(
              [row],
              {
                'p': {'cpf': '52998224725'},
              },
            ),
            onExport: (_) {
              calls++;
              return done.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receita-professional')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dentista').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receita-export-csv')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('receita-export-csv')));
    expect(calls, 1);
    done.completeError(StateError('failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível gerar'), findsOneWidget);
    expect(row.payerCpf, '52998224725');
  });
}
