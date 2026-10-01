import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/utils/async_memo.dart';

void main() {
  test('memoiza por chave: 2 gets disparam 1 fetch', () async {
    final memo = FutureMemo<String>();
    var calls = 0;
    Future<String> fetch() async {
      calls++;
      return 'v';
    }

    final a = memo.get('k', fetch);
    final b = memo.get('k', fetch);
    expect(await a, 'v');
    expect(await b, 'v');
    expect(calls, 1);
  });

  test('chaves distintas buscam separado', () async {
    final memo = FutureMemo<String>();
    expect(await memo.get('a', () async => 'A'), 'A');
    expect(await memo.get('b', () async => 'B'), 'B');
  });

  test('invalidate limpa uma chave', () async {
    final memo = FutureMemo<String>();
    var calls = 0;
    Future<String> fetch() async {
      calls++;
      return 'v$calls';
    }

    expect(await memo.get('k', fetch), 'v1');
    memo.invalidate('k');
    expect(await memo.get('k', fetch), 'v2');
    expect(calls, 2);
  });
}
