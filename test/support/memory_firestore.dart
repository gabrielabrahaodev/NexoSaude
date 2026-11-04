// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Small in-memory SDK double for service orchestration tests. Authorization
/// is checked separately by test/rules against the actual emulator.
class MemoryFirestore extends Fake implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{};
  bool failCommit = false;
  String? failQuery;
  final queries = <({String collection, Map<String, Object?> filters})>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  WriteBatch batch() => _Batch(this);
}

class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.db, this.path);
  final MemoryFirestore db;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(this, db.docs[path]);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    db.docs[path] = {...?db.docs[path], ...data};
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.reference, this.value);
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? value;
  @override
  String get id => reference.id;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value == null ? null : Map.of(value!);
}

class _Doc extends _Snapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(super.reference, super.value);
  @override
  Map<String, dynamic> data() => Map.of(value!);
}

class _Result extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Result(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.db, this.path, [this.filters = const {}, this.maximum = 100000]);
  final MemoryFirestore db;
  final String path;
  final Map<String, Object?> filters;
  final int maximum;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #where) {
      final field = call.positionalArguments.first as String;
      return _Query(db, path, {
        ...filters,
        field: call.namedArguments[#whereIn] ?? call.namedArguments[#isEqualTo],
      }, maximum);
    }
    if (call.memberName == #limit) {
      return _Query(db, path, filters, call.positionalArguments.first as int);
    }
    if (call.memberName == #get) return _get();
    return super.noSuchMethod(call);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _get() async {
    db.queries.add((collection: path, filters: filters));
    if (db.failQuery == path) throw StateError('query failed');
    return _Result(
      [
        for (final e in db.docs.entries)
          if (e.key.split('/').length == 2 &&
              e.key.startsWith('$path/') &&
              filters.entries.every(
                (f) => f.value is List
                    ? (f.value as List).contains(e.value[f.key])
                    : e.value[f.key] == f.value,
              ))
            _Doc(_Ref(db, e.key), e.value),
      ].take(maximum).toList(),
    );
  }
}

class _Collection extends _Query
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(super.db, super.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Ref(db, '${this.path}/$path');
}

class _Batch extends Fake implements WriteBatch {
  _Batch(this.db);
  final MemoryFirestore db;
  final changes = <void Function()>[];
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #delete || call.memberName == #update) {
      final ref = call.positionalArguments.first as DocumentReference;
      changes.add(() {
        if (call.memberName == #delete) {
          db.docs.remove(ref.path);
        } else {
          db.docs[ref.path]!.addAll(
            call.positionalArguments[1] as Map<String, dynamic>,
          );
        }
      });
      return this;
    }
    return super.noSuchMethod(call);
  }

  @override
  Future<void> commit() async {
    if (db.failCommit) throw StateError('commit failed');
    for (final change in changes) {
      change();
    }
  }
}
