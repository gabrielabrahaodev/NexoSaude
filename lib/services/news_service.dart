import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';
import '../models/news_model.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Notícias científicas por tema da clínica (dental/psico).
///
/// Fontes JSON com CORS liberado (sem proxy):
/// - Europe PMC (primária): https://www.ebi.ac.uk/europepmc
/// - Semantic Scholar (backup): https://api.semanticscholar.org
/// Tradução pt-BR com cache; falha traduzindo = texto original.
class NewsService {
  // Cache em memória para evitar re-traduções e detectar duplicatas
  final Map<String, OrthoArticle> _cache = {};
  // Quando cada id ENTROU no cache (evicção por idade de fetch, não do
  // artigo: Europe PMC só dá o ano e viria datado de 1º/jan).
  final Map<String, DateTime> _fetchedAt = {};
  DateTime? _lastFetch;
  String? _lastTheme;

  static const _queries = {
    'dental': 'orthodontics dentistry',
    'psychology': 'psychotherapy psychology',
  };

  String _queryFor(String clinicType) =>
      _queries[clinicType.toLowerCase()] ?? _queries['dental']!;

  Future<List<OrthoArticle>> getLatestOrthoNews(
      {bool forceRefresh = false, String clinicType = 'dental'}) async {
    final now = DateTime.now();

    // 1. LIMPA ITENS FETCHADOS HÁ +30 DIAS (não pela data do artigo)
    _cache.removeWhere((id, article) {
      final fetched = _fetchedAt[id];
      if (fetched == null) return true;
      return now.difference(fetched).inDays > 30;
    });

    // 2. Retorna cache se recente (< 60 minutos), mesmo tema, sem forçar
    if (!forceRefresh &&
        _cache.isNotEmpty &&
        _lastFetch != null &&
        _lastTheme == clinicType) {
      final age = now.difference(_lastFetch!);
      if (age < const Duration(minutes: 60)) {
        debugPrint('Cache válido: ${_cache.length} notícias (${age.inMinutes}m)');
        return _sortedCache();
      }
    }

    // 3. Fetch novas notícias (primária + backup)
    final query = _queryFor(clinicType);
    var raws = await _fetchEuropePmc(query);
    if (raws.isEmpty) {
      debugPrint('Europe PMC vazio. Usando Semantic Scholar...');
      raws = await _fetchSemanticScholar(query);
    }

    // 4. Traduz em paralelo + merge com cache (evita duplicatas)
    final translator = GoogleTranslator();
    int addedCount = 0;
    await Future.wait(raws.take(10).map((r) async {
      final idSource = '${r.title.trim().toLowerCase()}|${r.url}';
      final uniqueId = sha1.convert(utf8.encode(idSource)).toString();
      if (_cache.containsKey(uniqueId)) return;
      final translatedTitle =
          await _translateWithCache(translator, r.title);
      var translatedSummary = '';
      if (r.summary.isNotEmpty) {
        final truncated = r.summary.length > 280
            ? '${r.summary.substring(0, 280)}...'
            : r.summary;
        translatedSummary =
            await _translateWithCache(translator, truncated);
      }
      _cache[uniqueId] = OrthoArticle(
        id: uniqueId,
        title: translatedTitle.isNotEmpty ? translatedTitle : r.title,
        summary: translatedSummary,
        source: r.source,
        url: r.url,
        date: r.date,
      );
      _fetchedAt[uniqueId] = DateTime.now();
      addedCount++;
    }));

    // 5. Limita cache total (máx 30 notícias)
    if (_cache.length > 30) {
      final sorted = _sortedCache();
      _cache.clear();
      _fetchedAt.clear();
      for (var i = 0; i < 30 && i < sorted.length; i++) {
        _cache[sorted[i].id] = sorted[i];
        _fetchedAt[sorted[i].id] = now;
      }
    }

    _lastFetch = now;
    _lastTheme = clinicType;
    debugPrint('Adicionadas $addedCount novas. Total: ${_cache.length}');
    return _sortedCache();
  }

  // Helper para ordenar cache
  List<OrthoArticle> _sortedCache() {
    return _cache.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Bruto da API (sem tradução) — formato interno.
  /// Puro o parse; o fetch é glue (sem teste, depende da rede).
  Future<List<RawArticle>> _fetchEuropePmc(String query) async {
    try {
      final uri = Uri.parse(
          'https://www.ebi.ac.uk/europepmc/webservices/rest/search'
          '?query=${Uri.encodeQueryComponent(query)}'
          '&format=json&pageSize=15&sort=PUB_YEAR%20desc');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('Europe PMC status ${response.statusCode}');
        return [];
      }
      return parseEuropePmc(response.body);
    } catch (e) {
      debugPrint('Erro Europe PMC: $e');
      return [];
    }
  }

  Future<List<RawArticle>> _fetchSemanticScholar(String query) async {
    try {
      final uri = Uri.parse(
          'https://api.semanticscholar.org/graph/v1/paper/search'
          '?query=${Uri.encodeQueryComponent(query)}'
          '&limit=15&fields=title,abstract,url,publicationDate,externalIds');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('Semantic Scholar status ${response.statusCode}');
        return [];
      }
      return parseSemanticScholar(response.body);
    } catch (e) {
      debugPrint('Erro Semantic Scholar: $e');
      return [];
    }
  }

  // Cache simples de tradução (evita re-traduzir mesmas frases)
  final Map<String, String> _translationCache = {};

  Future<String> _translateWithCache(
      GoogleTranslator translator, String text) async {
    if (text.isEmpty) return '';

    final cacheKey = '${text.hashCode}_pt';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      final result = await translator.translate(text, to: 'pt');
      _translationCache[cacheKey] = result.text;
      return result.text;
    } catch (e) {
      debugPrint('Falha tradução: $e');
      return text; // Fallback para original
    }
  }
}

/// Limpa markup das APIs (tags + entidades HTML) ANTES de traduzir.
/// Puro e testado.
String cleanText(String raw) {
  if (raw.isEmpty) return '';
  var s = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
  const entities = {
    '&lt;': '<',
    '&gt;': '>',
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(
      RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)));
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Artigo bruto (pré-tradução). Parse puro e testado.
class RawArticle {
  final String title;
  final String summary;
  final String source;
  final String url;
  final DateTime date;

  const RawArticle({
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.date,
  });
}

/// Parse do JSON do Europe PMC (resultList.result[]).
List<RawArticle> parseEuropePmc(String body) {
  final out = <RawArticle>[];
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results =
        ((json['resultList'] as Map?)?['result'] as List?) ?? [];
    for (final e in results) {
      final m = Map<String, dynamic>.from(e as Map);
      final title = cleanText('${m['title'] ?? ''}');
      if (title.isEmpty) continue;
      final pmid = '${m['pmid'] ?? ''}';
      final doi = '${m['doi'] ?? ''}';
      final url = pmid.isNotEmpty
          ? 'https://europepmc.org/article/MED/$pmid'
          : (doi.isNotEmpty ? 'https://doi.org/$doi' : '');
      if (url.isEmpty) continue;
      out.add(RawArticle(
        title: title,
        summary: cleanText('${m['abstractText'] ?? ''}'),
        source: 'Europe PMC',
        url: url,
        date: _europePmcDate(m),
      ));
    }
  } catch (e) {
    debugPrint('Parse Europe PMC falhou: $e');
  }
  return out;
}

DateTime _europePmcDate(Map<String, dynamic> m) {
  final y = int.tryParse('${m['pubYear'] ?? ''}');
  if (y == null) return DateTime.now();
  return DateTime(y, 1, 1);
}

/// Parse do JSON do Semantic Scholar (data[]).
List<RawArticle> parseSemanticScholar(String body) {
  final out = <RawArticle>[];
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = (json['data'] as List?) ?? [];
    for (final e in results) {
      final m = Map<String, dynamic>.from(e as Map);
      final title = cleanText('${m['title'] ?? ''}');
      final url = cleanText('${m['url'] ?? ''}');
      if (title.isEmpty || url.isEmpty) continue;
      DateTime date;
      try {
        date = DateTime.parse('${m['publicationDate']}');
      } catch (_) {
        date = DateTime.now().subtract(const Duration(days: 1));
      }
      out.add(RawArticle(
        title: title,
        summary: cleanText('${m['abstract'] ?? ''}'),
        source: 'Semantic Scholar',
        url: url,
        date: date,
      ));
    }
  } catch (e) {
    debugPrint('Parse Semantic Scholar falhou: $e');
  }
  return out;
}
