import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odonto_controle/screens/financial/clinical_collections_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';
import 'collection_queue_test.dart' as f;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  for (final dark in [true, false]) {
    for (final width in [320.0, 390.0, 768.0, 1040.0, 1440.0]) {
      testWidgets(
        'collections $width dark=$dark selection, actions, unit, search',
        (tester) async {
          AppColors.isDark = dark;
          addTearDown(() => AppColors.isDark = false);
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final q = f.queue([f.fin('d'), f.fin('p', clinic: 'p')]);
          final actions = <String>[];
          int month = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(dark: dark),
              home: ClinicalCollectionsView(
                month: f.now,
                queue: q,
                onMonth: (i) => month += i,
                onExport: (r, id) => actions.add('export:${r.length}'),
                onBatch: (r) => actions.add('batch:${r.length}'),
                onCopy: (c) => actions.add('copy:${c.key}'),
                onSend: (c) => actions.add('send:${c.key}'),
                onReceive: (c) => actions.add('receive:${c.key}'),
                onReschedule: (c) => actions.add('delay:${c.key}'),
                onPatient: (c) => actions.add('patient:${c.key}'),
                onRetry: () => actions.add('retry'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          Future<void> click(String key) async {
            final findKey = find.byKey(ValueKey(key));
            await tester.ensureVisible(findKey);
            await tester.pumpAndSettle();
            await tester.tap(findKey);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          await click('collections-next');
          expect(month, 1);
          await click('collections-export');
          await click('collections-batch');
          expect(actions, containsAll(['export:2', 'batch:2']));
          await click('collection-single:p');
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('collection-selected-name')),
                )
                .data,
            'Ana',
          );
          await click('collection-copy');
          await click('collection-send');
          await click('collection-receive');
          await click('collection-reschedule');
          expect(
            actions,
            containsAll([
              'copy:single:p',
              'send:single:p',
              'receive:single:p',
              'delay:single:p',
            ]),
          );
          await click('collection-patient-single:d');
          expect(actions, contains('patient:single:d'));
          await click('collections-unit-p');
          expect(
            find.byKey(const ValueKey('collection-single:d')),
            findsNothing,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('collections-search')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('collections-search')),
            'inexistente',
          );
          await tester.pumpAndSettle();
          expect(find.text('Nenhuma cobrança nesta seleção.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('errors and load never expose old amount or active action', (
    tester,
  ) async {
    AppColors.isDark = true;
    addTearDown(() => AppColors.isDark = false);
    for (final loading in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ClinicalCollectionsView(
            month: f.now,
            queue: f.queue([f.fin('d')]),
            loading: loading,
            error: loading ? null : 'Falha de leitura',
            onMonth: (_) {},
            onExport: (_, unit) => fail('export'),
            onBatch: (_) => fail('batch'),
            onCopy: (_) {},
            onSend: (_) {},
            onReceive: (_) {},
            onReschedule: (_) {},
            onPatient: (_) {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('collection-single:d')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('collections-export')),
            )
            .onPressed,
        isNull,
      );
    }
  });
}
