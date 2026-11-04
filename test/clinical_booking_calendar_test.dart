import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odonto_controle/widgets/clinical_booking_calendar.dart';
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  for (final width in [320.0,1200.0]) {
    testWidgets('booking calendar selects day and navigates month $width', (t) async {
      t.view.physicalSize=Size(width,900); t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      DateTime? selected;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: ClinicalBookingCalendar(selected: DateTime(2026,11,3),onChanged:(v)=>selected=v))));
      await t.tap(find.text('5')); expect(selected,DateTime(2026,11,5));
      await t.tap(find.byTooltip('Próximo mês')); await t.pump();
      expect(find.text('dezembro 2026'),findsOneWidget); expect(t.takeException(),isNull);
    });
  }
}
