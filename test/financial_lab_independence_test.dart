// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/financial_service.dart';
import 'package:odonto_controle/services/session_manager.dart';

class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.path, this.value);
  final String path;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  DocumentReference<Map<String, dynamic>> get reference => _Ref(path);
}

class _Result extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Result(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Rows extends Fake implements Query<Map<String, dynamic>> {
  _Rows(this.db, this.path, [this.filters = const []]);
  final _Db db;
  final String path;
  final List<bool Function(Map<String, dynamic>)> filters;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #where) {
      final field = call.positionalArguments.first as String;
      final values = call.namedArguments[#whereIn] as List?;
      final value = call.namedArguments[#isEqualTo];
      return _Rows(db, path, [
        ...filters,
        (data) => values == null
            ? data[field] == value
            : values.contains(data[field]),
      ]);
    }
    if (call.memberName == #get) {
      return Future<QuerySnapshot<Map<String, dynamic>>>.value(
        _Result([
          for (final e in db.docs.entries)
            if (e.key.startsWith('$path/') && filters.every((f) => f(e.value)))
              _Doc(e.key, e.value),
        ]),
      );
    }
    return super.noSuchMethod(call);
  }
}

class _Collection extends _Rows
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(super.db, super.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Ref('${this.path}/$path');
}

class _Batch extends Fake implements WriteBatch {
  _Batch(this.db);
  final _Db db;
  final changes = <void Function()>[];
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #delete) {
      final ref = call.positionalArguments.first as DocumentReference;
      changes.add(() => db.docs.remove(ref.path));
      return this;
    }
    if (call.memberName == #update) {
      final ref = call.positionalArguments.first as DocumentReference;
      final data = call.positionalArguments[1] as Map<String, dynamic>;
      changes.add(() => db.docs[ref.path]!.addAll(data));
      return this;
    }
    return super.noSuchMethod(call);
  }

  @override
  Future<void> commit() async {
    for (final change in changes) {
      change();
    }
  }
}

class _Db extends Fake implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{
    'financial/f1': {'clinicId': 'c1', 'status': 'paid'},
    'expenses/commission': {'clinicId': 'c1', 'relatedFinancialId': 'f1'},
    'expenses/labCost': {
      'clinicId': 'c1',
      'relatedFinancialId': 'f1',
      'source': 'lab_order',
    },
    'expenses/otherClinic': {'clinicId': 'c2', 'relatedFinancialId': 'f1'},
    'lab_orders/oldOrder': {'clinicId': 'c1', 'relatedFinancialId': 'f1'},
  };
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  WriteBatch batch() => _Batch(this);
}

void main() {
  test(
    'cancelar família preserva laboratório/custo e não toca outra clínica',
    () async {
      SessionManager().setClinic('c1', 'Clínica', 'dental');
      final db = _Db();
      await FinancialService(firestore: db).cancelFamily(['f1']);
      expect(db.docs['financial/f1']!['status'], 'cancelado');
      expect(db.docs['expenses/commission'], isNull);
      expect(db.docs['expenses/labCost'], isNotNull);
      expect(db.docs['expenses/otherClinic'], isNotNull);
      expect(db.docs['lab_orders/oldOrder'], isNotNull);
    },
  );
}
