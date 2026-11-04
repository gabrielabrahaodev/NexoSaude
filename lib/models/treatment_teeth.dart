/// Reads explicit tooth references only; procedure names never imply a link.
List<int> treatmentLinkedTeeth(Map<String, dynamic> plan) {
  final ids = <int>{};
  void collect(dynamic value) {
    if (value is List) {
      for (final v in value) {
        collect(v);
      }
      return;
    }
    if (value is Map) {
      collect(value['id'] ?? value['number']);
      return;
    }
    final id = value is num && value == value.toInt()
        ? value.toInt()
        : int.tryParse('$value');
    if (id != null &&
        [1, 2, 3, 4].contains(id ~/ 10) &&
        id % 10 >= 1 &&
        id % 10 <= 8) {
      ids.add(id);
    }
  }

  void fromRecord(Map record) {
    for (final key in [
      'teeth',
      'toothIds',
      'toothId',
      'tooth',
      'dentes',
      'dente',
    ]) {
      collect(record[key]);
    }
  }

  fromRecord(plan);
  final items = plan['items'];
  if (items is List) {
    for (final item in items) {
      if (item is Map) fromRecord(item);
    }
  }
  return ids.toList()..sort();
}
