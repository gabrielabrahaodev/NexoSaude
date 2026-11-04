import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odonto_controle/screens/agenda/clinical_booking_view.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  for (final dark in [false, true]) {
    for (final height in [1000.0, 1080.0]) {
      testWidgets('booking fits 1920x$height dark=$dark including six-week month', (t) async {
        t.view.physicalSize=Size(1920,height); t.view.devicePixelRatio=1;
        addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
        final notes=TextEditingController(); addTearDown(notes.dispose);
        final times=[for(var i=480;i<=1200;i+=30) '${(i~/60).toString().padLeft(2,'0')}:${(i%60).toString().padLeft(2,'0')}'];
        var saved=0, newPatient=0, changed=0; bool fit=false;
        String? selectedTime;
        await t.pumpWidget(MaterialApp(theme: ThemeData(brightness:dark?Brightness.dark:Brightness.light),home: ClinicalBookingView(
          title:'Novo Agendamento',clinic:'Jabaquara',professional:'Dra. Laucieli Costa',
          patientField:const TextField(decoration:InputDecoration(isDense:true,hintText:'Paciente selecionado')),procedureField:const TextField(decoration:InputDecoration(isDense:true,hintText:'Manutenção ortodôntica')),
          patientSummary:'CPF: 341.***.***-08 • WhatsApp: (11) 98421-4402',recordNumber:'4092',procedureCategory:'Ortodontia',procedurePrice:220,
          tags:Container(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Tags de Procedimentos Vinculadas'),Wrap(spacing:8,children:[for(var i=0;i<8;i++)Chip(label:Text('Procedimento do orçamento • item $i'))])])),
          notesController:notes,selectedDate:DateTime(2026,8,5),times:times,selectedTimes:const ['11:00'],occupiedTimes:const ['09:00'],
          onDate:(_){},onTime:(s)=>selectedTime=s,onFitIn:(v)=>fit=v,onCancel:(){},onProcedure:(){},onNewPatient:()=>newPatient++,onChangePatient:()=>changed++,onSave:()=>saved++,
        )));
        await t.pumpAndSettle();
        final outer = find.descendant(of:find.byKey(const ValueKey('booking-scroll')),matching:find.byType(Scrollable)).first;
        expect(t.state<ScrollableState>(outer).position.maxScrollExtent,closeTo(0,1));
        expect(t.getRect(find.byKey(const ValueKey('booking-notes'))).bottom,lessThan(t.getRect(find.byKey(const ValueKey('booking-footer'))).top));
        await t.tap(find.byKey(const ValueKey('booking-confirm'))); expect(saved,1);
        await t.tap(find.text('Novo')); expect(newPatient,1);
        await t.tap(find.text('Alterar paciente')); expect(changed,1);
        final occupied = find.byKey(const ValueKey('booking-slot-09:00'));
        expect(t.widget<OutlinedButton>(occupied).onPressed,isNull);
        expect(find.descendant(of:occupied,matching:find.text('Ocupado')),findsOneWidget);
        expect(t.widget<OutlinedButton>(find.byKey(const ValueKey('booking-slot-10:00'))).onPressed,isNotNull);
        await t.tap(find.text('10:00')); expect(selectedTime,'10:00');
        await t.tap(find.byType(Checkbox)); expect(fit,true);
        expect(t.takeException(),isNull);
      });
    }
  }
}
