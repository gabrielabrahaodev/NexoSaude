import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/financial_model.dart';
import 'package:odonto_controle/services/financial_service.dart';

FinancialModel _doc(String id,
    {String? parentId,
    String? installmentNumber,
    String status = 'pago',
    double amount = 100}) {
  return FinancialModel(
    id: id,
    clinicId: 'c1',
    patientId: 'p1',
    patientName: 'Gabriel',
    title: 'T',
    description: '',
    amount: amount,
    paidAmount: status == 'pago' ? amount : 0.0,
    date: DateTime(2026, 9, 1),
    type: 'income',
    status: status,
    parentId: parentId,
    installmentNumber: installmentNumber,
  );
}

void main() {
  group('familyOf', () {
    test('filha acha pai + irmãs ordenadas', () {
      final parent = _doc('pai', status: 'substituido (parcelado)');
      final c2 = _doc('c2', parentId: 'pai', installmentNumber: '2/3');
      final c1 = _doc('c1', parentId: 'pai', installmentNumber: '1/3');
      final c3 = _doc('c3', parentId: 'pai', installmentNumber: '3/3');
      final other = _doc('outra');
      final fam = FinancialService.familyOf(
          [parent, c2, other, c1, c3], c2);
      expect(fam.parent?.id, 'pai');
      expect(fam.children.map((e) => e.id).toList(), ['c1', 'c2', 'c3']);
    });

    test('pai acha filhas; avulso volta vazio', () {
      final parent = _doc('pai', status: 'substituido (parcelado)');
      final c1 = _doc('c1', parentId: 'pai', installmentNumber: '1/2');
      final solo = _doc('solo');
      final fam = FinancialService.familyOf([parent, c1, solo], parent);
      expect(fam.children.map((e) => e.id).toList(), ['c1']);
      final famSolo =
          FinancialService.familyOf([parent, c1, solo], solo);
      expect(famSolo.parent, isNull);
      expect(famSolo.children, isEmpty);
    });

    test('filha órfã (pai deletado no legado) não quebra', () {
      final orphan =
          _doc('orf', parentId: 'sumido', installmentNumber: '1/2');
      final fam = FinancialService.familyOf([orphan], orphan);
      expect(fam.parent, isNull);
      expect(fam.children.map((e) => e.id).toList(), ['orf']);
    });
  });

  group('visibleCharges', () {
    test('esconde filhas com pai presente; órfãs ficam', () {
      final parent = _doc('pai', status: 'substituido (parcelado)');
      final c1 = _doc('c1', parentId: 'pai', installmentNumber: '1/2');
      final orphan =
          _doc('orf', parentId: 'sumido', installmentNumber: '1/2');
      final solo = _doc('solo');
      final vis =
          FinancialService.visibleCharges([parent, c1, orphan, solo]);
      expect(vis.map((e) => e.id).toList(), ['pai', 'orf', 'solo']);
    });
  });

  group('familyProgress', () {
    test('conta pagas sobre total', () {
      final kids = [
        _doc('c1', status: 'pago'),
        _doc('c2', status: 'pendente', amount: 100),
        _doc('c3', status: 'pago'),
      ];
      // c2 pendente: paidAmount 0
      final p = FinancialService.familyProgress(kids);
      expect(p.paid, 2);
      expect(p.total, 3);
    });
  });
}
