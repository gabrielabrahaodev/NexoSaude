import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/budget_delete_service.dart';
import 'package:odonto_controle/services/clinic_delete_service.dart';

void main() {
  test('contrato aprovado ou plano bloqueia exclusão mesmo com UI desatualizada', () {
    expect(budgetDeletionBlocked({'status':'Aprovado'}, approved:false), isTrue);
    expect(budgetDeletionBlocked({'relatedPlanId':'plan'}, approved:false), isTrue);
    expect(budgetDeletionBlocked({}, approved:true), isTrue);
    expect(budgetDeletionBlocked({'status':'pendente'}, approved:false), isFalse);
  });
  test('plano de clínica inclui Tags apenas dos pacientes comprovados', () {
    for (final patients in <List<String>>[[], ['one'], ['one','two','three']]) {
      final tags = clinicDeletePlan('clinic', patients).where((s) => s.path.endsWith('/procedure_tags'));
      expect(tags.length, patients.length);
      for (final step in tags) {
        expect(step.scopedTo('clinic', patients.toSet()), isTrue);
        expect(step.scopedTo('other', {}), isFalse);
      }
    }
  });
}
