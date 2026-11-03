import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odonto_controle/screens/patients/clinical_records_view.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  for (final dark in [true, false]) {
    for (final width in [390.0, 1200.0]) {
      testWidgets('records $width dark=$dark filters, operator and actions', (tester) async {
        AppColors.isDark = dark;
        addTearDown(() => AppColors.isDark = false);
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var created = 0;
        final edited = <String>[], deleted = <String>[];
        await tester.pumpWidget(MaterialApp(theme: PatientVisualStyle.theme, home: Scaffold(body: ClinicalRecordsView(
          records: [
            ClinicalRecordEntry('c', {'procedureName': 'Cancelamento de Consulta', 'description': 'Motivo: paciente solicitou.', 'dentistName': 'Cida', 'date': DateTime(2026, 10, 29)}),
            ClinicalRecordEntry('e', {'procedureName': 'Avaliação', 'description': 'Conduta registrada.', 'dentistName': 'Dra. Laucieli', 'treatmentId': 'plan', 'date': DateTime(2026, 9, 22)}),
            const ClinicalRecordEntry('a', {'procedureName': 'Cobrança via WhatsApp', 'description': 'Contato registrado.'}),
          ], onNew: () => created++, onEdit: edited.add, onDelete: deleted.add,
        ))));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancelamentos  1'));
        await tester.pump();
        expect(find.text('Cancelamento de Consulta'), findsOneWidget);
        expect(find.text('Avaliação'), findsNothing);
        expect(find.textContaining('Operador do registro: Cida'), findsOneWidget);
        await tester.tap(find.byTooltip('Editar registro'));
        await tester.tap(find.byTooltip('Excluir registro'));
        expect(edited, ['c']); expect(deleted, ['c']);
        await tester.tap(find.text('Evoluções  1'));
        await tester.pump();
        expect(find.text('Avaliação'), findsOneWidget);
        expect(find.text('Cobrança via WhatsApp'), findsNothing);
        await tester.tap(find.text('Novo Registro Clínico / Evolução'));
        expect(created, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
