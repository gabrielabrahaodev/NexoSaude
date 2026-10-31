import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/screens/reports/clinical_reports_view.dart';
import 'package:odonto_controle/screens/reports/report_entry_dialog.dart';
import 'package:odonto_controle/services/oracle_report_service.dart';
import 'package:odonto_controle/ui/app_theme.dart';

OracleReportSnapshot sample() => OracleReportService.calculateMonth(
  DateTime(2026, 10),
  [
    ReportDocument('income', {
      'patientName': 'Gabriel Teste',
      'title': 'Restauração em Resina Composta',
      'dentistName': 'Dra. Laucieli Costa',
      'amount': 660,
      'valorLiquido': 640,
      'status': 'paid',
      'date': DateTime(2026, 10, 26),
      'paymentMethod': 'Pix',
    }),
  ],
  [
    ReportDocument('lab', {
      'supplierName': 'Laboratório Precision',
      'description': 'Confecção de coroas',
      'category': 'Laboratório',
      'amount': 280,
      'status': 'pendente',
      'dueDate': DateTime(2026, 10, 28),
    }),
  ],
);
void main() {
  for (final dark in [true, false])
    for (final width in [390.0, 768.0, 1200.0]) {
      testWidgets('report $dark at $width, tabs and filters', (tester) async {
        AppColors.isDark = dark;
        addTearDown(() => AppColors.isDark = false);
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int exports = 0,
            expenses = 0,
            incomes = 0,
            months = 0,
            pays = 0,
            receita = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(dark: dark),
            home: Scaffold(
              body: ClinicalReportsView(
                month: DateTime(2026, 10),
                clinicName: 'Yervant',
                snapshot: sample(),
                receivables: const [],
                onMonth: (v) => months += v,
                onRefresh: () {},
                onExport: () => exports++,
                onReceitaSaude: () => receita++,
                onExpense: () => expenses++,
                onIncome: () => incomes++,
                onAnticipate: () {},
                onEntry: (t, a) {
                  if (a == 'pay') pays++;
                },
                onCashbook: () {},
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Exportar DRE'));
        await tester.tap(find.byKey(const ValueKey('report-receita-saude')));
        expect(receita, 1);
        await tester.tap(find.text('Nova Despesa'));
        await tester.tap(find.text('Novo Lançamento'));
        await tester.tap(find.byTooltip('Próximo mês'));
        expect([exports, expenses, incomes, months], [1, 1, 1, 1]);
        final tab = find.byKey(const ValueKey('report-tab-2'));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.text('Laboratório Precision'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final pay = find.byTooltip('Baixar pagamento');
        await tester.ensureVisible(pay);
        await tester.tap(pay);
        expect(pays, 1);
        final search = find.byKey(const ValueKey('report-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, 'inexistente');
        await tester.pumpAndSettle();
        expect(find.text('Laboratório Precision'), findsNothing);
        await tester.enterText(search, '');
        await tester.pumpAndSettle();
        for (final i in [1, 3, 0]) {
          final t = find.byKey(ValueKey('report-tab-$i'));
          await tester.ensureVisible(t);
          await tester.tap(t);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  testWidgets('entry validates BRL and blocks duplicate save and lost focus', (
    tester,
  ) async {
    final completer = Completer<void>();
    Map<String, dynamic>? saved;
    int writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(dark: true),
        home: Scaffold(
          body: ReportEntryDialog(
            income: false,
            month: DateTime(2026, 10),
            onSave: (v) {
              saved = v;
              writes++;
              return completer.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Informe a descrição'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Insumos');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      'Insumos',
    );
    await tester.enterText(fields.at(1), '1.234,56');
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pump();
    await tester.tap(find.text('Salvando…'));
    expect(writes, 1);
    expect(saved!['amount'], 1234.56);
    completer.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('entry save failure keeps typed fields and retries', (
    tester,
  ) async {
    int writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportEntryDialog(
            income: true,
            month: DateTime(2026, 10),
            onSave: (v) async {
              writes++;
              throw StateError('offline');
            },
          ),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Receita avulsa');
    await tester.enterText(fields.at(1), '300,00');
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(find.text('Receita avulsa'), findsOneWidget);
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();
    expect(writes, 2);
  });

  testWidgets(
    'live theme preserves selected tab and search; loading hides totals',
    (tester) async {
      Widget screen({bool loading = false, String? error}) => MaterialApp(
        theme: buildAppTheme(dark: AppColors.isDark),
        home: Scaffold(
          body: ClinicalReportsView(
            month: DateTime(2026, 10),
            clinicName: 'Yervant',
            snapshot: sample(),
            receivables: const [],
            onMonth: (_) {},
            onRefresh: () {},
            onExport: () {},
            onExpense: () {},
            onIncome: () {},
            onAnticipate: () {},
            onEntry: (_, __) {},
            onCashbook: () {},
            loading: loading,
            error: error,
          ),
        ),
      );
      AppColors.isDark = true;
      addTearDown(() => AppColors.isDark = false);
      await tester.pumpWidget(screen());
      final tab = find.byKey(const ValueKey('report-tab-2'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('report-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Precision');
      await tester.pumpAndSettle();
      AppColors.isDark = false;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Precision'), findsOneWidget);
      expect(find.text('Laboratório Precision'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(screen(loading: true));
      await tester.pump();
      expect(find.text('Laboratório Precision'), findsNothing);
      expect(find.text('—'), findsNWidgets(5));
      await tester.pumpWidget(screen(error: 'Falha ao carregar'));
      await tester.pumpAndSettle();
      expect(find.text('Falha ao carregar'), findsNWidgets(2));
      expect(find.text('—'), findsNWidgets(5));
    },
  );
}
