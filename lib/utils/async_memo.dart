/// Memoiza futures por chave: gets repetidos reaproveitam o mesmo
/// future (sem refetch) enquanto pendente ou já resolvido.
/// `invalidate` força nova busca (ex.: após escrita que muda o dado).
class FutureMemo<T> {
  final _cache = <String, Future<T>>{};

  Future<T> get(String key, Future<T> Function() fetch) =>
      _cache.putIfAbsent(key, fetch);

  void invalidate(String key) => _cache.remove(key);

  void clear() => _cache.clear();
}
