import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/news_service.dart';

void main() {
  group('parseEuropePmc', () {
    test('extrai título, doi/pmid e data', () {
      const body = '''
{"resultList": {"result": [
  {"title": "Clear aligners review", "abstractText": "Abstract here",
   "pmid": "12345", "doi": "10.1/abc", "pubYear": "2026"},
  {"title": "", "pmid": "999"},
  {"title": "No link", "pubYear": "2025"}
]}}''';
      final out = parseEuropePmc(body);
      expect(out.length, 1);
      expect(out.first.title, 'Clear aligners review');
      expect(out.first.url, 'https://europepmc.org/article/MED/12345');
      expect(out.first.date, DateTime(2026, 1, 1));
      expect(out.first.source, 'Europe PMC');
    });

    test('json inválido retorna vazio', () {
      expect(parseEuropePmc('não-json'), isEmpty);
    });
  });

  group('parseSemanticScholar', () {
    test('extrai título, url e data', () {
      const body = '''
{"data": [
  {"title": "Therapy outcomes", "abstract": "Abs",
   "url": "https://example.org/p1", "publicationDate": "2026-08-15"},
  {"title": "Sem url"}
]}''';
      final out = parseSemanticScholar(body);
      expect(out.length, 1);
      expect(out.first.url, 'https://example.org/p1');
      expect(out.first.date, DateTime(2026, 8, 15));
    });
  });
}
