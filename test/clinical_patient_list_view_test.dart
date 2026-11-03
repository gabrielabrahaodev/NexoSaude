import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/patient_list_entry.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_list_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

List<PatientListEntry> fixture() => [
  const PatientListEntry('a', {
    'name': 'Ana Andrade',
    'clinicId': 'c',
    'phone': '(11) 98888-1111',
    'cpf': '123.123.123-12',
    'recordNumber': '4819',
    'lgpdPortalConsent': {'accepted': true},
  }),
  const PatientListEntry('b', {
    'name': 'Bruno Teste',
    'clinicId': 'c',
    'phone': '',
    'status': 'Ativo',
  }),
];
const listContext = PatientListContext(
  debts: {'a': 600},
  treatments: {'a'},
  budgets: {'a'},
);
void main() {
  for (final dark in [true, false]) {
    for (final width in [320.0, 390.0, 768.0, 1280.0]) {
      testWidgets('list $width dark=$dark filters, open, export and menu', (
        tester,
      ) async {
        AppColors.isDark = dark;
        addTearDown(() => AppColors.isDark = false);
        tester.view.physicalSize = Size(width, width < 500 ? 700 : 1050);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final opened = <String>[];
        int creates = 0, deletes = 0;
        List<PatientListEntry>? exported;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(dark: dark),
            home: ClinicalPatientListView(
              patients: fixture(),
              contextData: listContext,
              onOpen: (p) => opened.add(p.id),
              onDelete: (_) => deletes++,
              onNew: () => creates++,
              onExport: (r) => exported = r,
              onRefresh: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final first = find.byKey(const ValueKey('patient-open-a'));
        await tester.scrollUntilVisible(
          first,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(opened, ['a']);
        final menu = find.byTooltip('Opções de Ana Andrade');
        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excluir Paciente'));
        await tester.pumpAndSettle();
        expect(deletes, 1);
        expect(opened, ['a']);
        final filter = find.byKey(const ValueKey('patient-filter-noConsent'));
        await tester.scrollUntilVisible(
          filter,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(filter);
        await tester.pumpAndSettle();
        expect(find.text('Ana Andrade'), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('patient-open-b')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Bruno Teste'), findsOneWidget);
        final export = find.byKey(const ValueKey('patient-list-export'));
        await tester.scrollUntilVisible(
          export,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(export);
        expect(exported!.map((p) => p.id), ['b']);
        await tester.tap(
          find.byKey(const ValueKey('patient-list-new-floating')),
        );
        expect(creates, 1);
        final search = find.byKey(const ValueKey('patient-list-search'));
        await tester.scrollUntilVisible(
          search,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(search, 'Nao existe');
        await tester.pumpAndSettle();
        expect(
          find.text('Nenhum paciente encontrado para os filtros selecionados.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Ctrl K focuses search; live theme keeps draft and filter', (
    tester,
  ) async {
    Widget app() => MaterialApp(
      theme: buildAppTheme(dark: AppColors.isDark),
      home: ClinicalPatientListView(
        patients: fixture(),
        contextData: listContext,
        onOpen: (_) {},
        onDelete: (_) {},
        onNew: () {},
        onExport: (_) {},
        onRefresh: () {},
      ),
    );
    AppColors.isDark = true;
    addTearDown(() => AppColors.isDark = false);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final search = find.byKey(const ValueKey('patient-list-search'));
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, true);
    await tester.enterText(search, 'Bruno');
    await tester.pump();
    AppColors.isDark = false;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'Bruno');
    expect(find.text('Bruno Teste'), findsOneWidget);
    expect(find.text('Ana Andrade'), findsNothing);
  });
  testWidgets('complementary error keeps patients, disables unproven filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClinicalPatientListView(
          patients: fixture(),
          contextData: const PatientListContext(),
          contextError: 'offline',
          onOpen: (_) {},
          onDelete: (_) {},
          onNew: () {},
          onExport: (_) {},
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Andrade'), findsOneWidget);
    final chip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('patient-filter-debt')),
    );
    expect(chip.onSelected, isNull);
    expect(
      find.textContaining('Dados complementares indisponíveis'),
      findsOneWidget,
    );
    expect(find.textContaining('Pendência R'), findsNothing);
  });
}
