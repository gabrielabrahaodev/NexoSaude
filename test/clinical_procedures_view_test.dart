import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/procedure_model.dart';
import 'package:odonto_controle/screens/operations/clinical_procedures_view.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 768.0, 1440.0]) {
      testWidgets('procedures filters and actions $width dark=$dark', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var created = 0;
        final edited = <String>[], deleted = <String>[];
        await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light), home: ClinicalProceduresView(
          items: [ProcedureModel(id: 'a', clinicId: 'c', name: 'Raspagem', category: 'Geral', price: 300), ProcedureModel(id: 'b', clinicId: 'c', name: 'Restauração', category: 'Dentística', price: 250, hasCost: true, commissionValue: 40)],
          onNew: () => created++, onEdit: (p) => edited.add(p.id), onDelete: (p) => deleted.add(p.id),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Novo Procedimento'));
        expect(created, 1);
        await tester.enterText(find.byType(TextField), 'Raspagem');
        await tester.pumpAndSettle();
        expect(find.text('Raspagem'), findsOneWidget);
        expect(find.text('Restauração'), findsNothing);
        final edit = find.byTooltip('Editar Raspagem');
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        expect(edited, ['a']);
        await tester.tap(find.byTooltip('Excluir Raspagem'));
        expect(deleted, ['a']);
        await tester.enterText(find.byType(TextField), 'inexistente');
        await tester.pumpAndSettle();
        expect(find.text('Nenhum procedimento encontrado'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
