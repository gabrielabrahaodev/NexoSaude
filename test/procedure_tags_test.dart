import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/procedure_tags.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('catalog snapshot and patient line preserve contracted values', () {
    final template = procedureTagDefinition({'clinicId':'c','name':'Resina','price':250,'hasCost':true,'commissionValue':40}, 'proc');
    final tag = patientProcedureTag(clinicId:'c',patientId:'p',patientName:'Paciente',budgetId:'b',planId:'plan',index:0,line:{'id':'proc','name':'Resina','price':200,'quantity':2,'region':'22'},definition:template);
    expect((tag['lineSnapshot'] as Map)['price'], 200);
    expect(((tag['definitionSnapshot'] as Map)['procedureSnapshot'] as Map)['price'],250);
    expect(tag['status'],'pending'); expect(tag['sessionCount'],0);
    expect(patientTagId('b',0), isNot(patientTagId('b',1)));
    expect(patientTagId('b',0), isNot(patientTagId('other',0)));
    expect(tagSnapshotKey({'a':1,'b':[2]}),tagSnapshotKey({'b':[2],'a':1}));
  });
  test('appointments serialize and restore selected tags without changing date', () {
    final date = DateTime(2026,11,6,12,30);
    final a = AppointmentModel.fromMap('a',{'clinicId':'c','patientId':'p','date':Timestamp.fromDate(date),'procedureTagIds':['b0','b1']});
    expect(a.procedureTagIds,['b0','b1']);
    expect(a.toMap()['procedureTagIds'],['b0','b1']);
    expect(a.date,date);
  });
}
