import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/screens/patients/patient_workspace.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'paciente ocupa a região direita sem recriar menu ou empilhar rotas em $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final routes = _Routes();
        String clinic = 'clinic-a';
        late StateSetter update;
        Widget workspace() => PatientWorkspace(
          key: ValueKey(clinic),
          listBuilder: (_, open) => Column(
            children: [
              const TextField(key: ValueKey('search')),
              TextButton(
                onPressed: () => open('p1', 'Gabriel'),
                child: const Text('Abrir paciente'),
              ),
            ],
          ),
          detailBuilder: (_, id, name, close) => Column(
            children: [
              Text('$id $name', key: const ValueKey('detail')),
              TextButton(onPressed: close, child: const Text('Voltar à lista')),
            ],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [routes],
            home: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Scaffold(
                  body: Row(
                    children: [
                      const SizedBox(
                        key: ValueKey('menu'),
                        width: 100,
                        child: Text('Menu original'),
                      ),
                      Expanded(child: workspace()),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        final menu = tester.element(find.byKey(const ValueKey('menu')));
        await tester.enterText(find.byKey(const ValueKey('search')), 'Gabriel');
        await tester.tap(find.text('Abrir paciente'));
        await tester.pumpAndSettle();
        expect(find.text('p1 Gabriel'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('detail'))).left,
          greaterThanOrEqualTo(100),
        );
        expect(
          identical(tester.element(find.byKey(const ValueKey('menu'))), menu),
          isTrue,
        );
        expect(routes.pushes, 1);
        await tester.tap(find.text('Voltar à lista'));
        await tester.pumpAndSettle();
        expect(find.text('p1 Gabriel'), findsNothing);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Gabriel',
        );
        await tester.tap(find.text('Abrir paciente'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('p1 Gabriel'), findsNothing);
        expect(routes.pushes, 1);
        await tester.tap(find.text('Abrir paciente'));
        await tester.pumpAndSettle();
        update(() => clinic = 'clinic-b');
        await tester.pumpAndSettle();
        expect(find.text('p1 Gabriel'), findsNothing);
        expect(find.text('Abrir paciente'), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
