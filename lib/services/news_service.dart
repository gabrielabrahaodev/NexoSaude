import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:translator/translator.dart';
import '../models/news_model.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart'; // Adicione no pubspec: crypto: ^3.0.3

class NewsService {
  final String _primaryFeedUrl = 'https://www.google.com.br/alerts/feeds/11424108244178326930/7443775849462190253';
  final String _backupFeedUrl = 'https://www.sciencedaily.com/rss/health_medicine/dentistry.xml';
  
  // Cache em memória para evitar re-traduções e detectar duplicatas
  final Map<String, OrthoArticle> _cache = {};
  DateTime? _lastFetch;

  Future<List<OrthoArticle>> getLatestOrthoNews({bool forceRefresh = false}) async {
  final now = DateTime.now();
  
  // 1. LIMPA NOTÍCIAS ANTIGAS DO CACHE (mais de 7 dias)
  _cache.removeWhere((id, article) {
    final age = now.difference(article.date);
    return age.inDays > 7;  // Mantém só últimos 7 dias
  });

  // 2. Retorna cache se for recente (< 15 minutos) e não forçar refresh
  if (!forceRefresh && _cache.isNotEmpty && _lastFetch != null) {
    final age = now.difference(_lastFetch!);
    if (age < const Duration(minutes: 15)) {  // Aumentado para 15min
      debugPrint('Cache válido: ${_cache.length} notícias (${age.inMinutes}m)');
      return _sortedCache();
    }
  }

  // 3. Fetch novas notícias
  List<OrthoArticle> newArticles = await _fetchFeed(_primaryFeedUrl, isGoogleAlert: true);
  
  if (newArticles.isEmpty) {
    debugPrint("Google Alerts vazio. Usando backup...");
    newArticles = await _fetchFeed(_backupFeedUrl, isGoogleAlert: false);
  }

  // 4. FILTRA SOMENTE NOTÍCIAS DOS ÚLTIMOS 7 DIAS
  final sevenDaysAgo = now.subtract(const Duration(days: 7));
  newArticles = newArticles.where((a) => a.date.isAfter(sevenDaysAgo)).toList();

  // 5. Merge com cache (evita duplicatas)
  int addedCount = 0;
  for (var article in newArticles) {
    if (!_cache.containsKey(article.id)) {
      _cache[article.id] = article;
      addedCount++;
    }
  }
  
  // 6. Limita cache total (máx 30 notícias)
  if (_cache.length > 30) {
    final sorted = _sortedCache();
    _cache.clear();
    for (var i = 0; i < 30 && i < sorted.length; i++) {
      _cache[sorted[i].id] = sorted[i];
    }
  }

  _lastFetch = now;
  debugPrint('Adicionadas $addedCount novas. Total: ${_cache.length} (filtro: 7 dias)');
  
  return _sortedCache();
}

// Helper para ordenar cache
List<OrthoArticle> _sortedCache() {
  return _cache.values.toList()..sort((a, b) => b.date.compareTo(a.date));
}

  Future<List<OrthoArticle>> _fetchFeed(String url, {required bool isGoogleAlert}) async {
    final translator = GoogleTranslator();
    
    try {
      Uri uri = kIsWeb 
        ? Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(url)}')
        : Uri.parse(url);

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw HttpException('Status ${response.statusCode}');
      }

      final document = XmlDocument.parse(response.body);
      final tag = isGoogleAlert ? 'entry' : 'item';
      final entries = document.findAllElements(tag);
      
      List<OrthoArticle> articles = [];

      for (var entry in entries.take(10)) { // Aumentado para 10
        // Extração robusta
        final rawTitle = entry.findElements('title').firstOrNull?.innerText ?? '';
        final rawContent = isGoogleAlert 
          ? entry.findElements('content').firstOrNull?.innerText 
          : entry.findElements('description').firstOrNull?.innerText;
        
        final cleanTitle = _removeHtmlTags(rawTitle);
        final cleanContent = _removeHtmlTags(rawContent ?? '');
        
        // PULA NOTÍCIAS SEM CONTEÚDO RELEVANTE
        if (cleanTitle.isEmpty || cleanTitle.toLowerCase().contains('no title')) continue;

        // Data precisa
        final dateString = isGoogleAlert 
          ? entry.findElements('updated').firstOrNull?.innerText 
          : entry.findElements('pubDate').firstOrNull?.innerText;
        final date = _parseDate(dateString) ?? DateTime.now();

        // Link
        String link = '';
        if (isGoogleAlert) {
          link = entry.findElements('link').firstOrNull?.getAttribute('href') ?? '';
        } else {
          link = entry.findElements('link').firstOrNull?.innerText ?? '';
        }

        // ID ÚNICO BASEADO EM CONTEÚDO (não em timestamp)
        // Usa hash SHA1 do título + link para identificar notícia única
        final idSource = '${cleanTitle.trim().toLowerCase()}|$link';
        final uniqueId = sha1.convert(utf8.encode(idSource)).toString();

        // Tradução com cache simples
        final translatedTitle = await _translateWithCache(translator, cleanTitle);
        String translatedSummary = '';
        if (cleanContent.isNotEmpty) {
          final truncated = cleanContent.length > 280 
            ? '${cleanContent.substring(0, 280)}...' 
            : cleanContent;
          translatedSummary = await _translateWithCache(translator, truncated);
        }

        articles.add(OrthoArticle(
          id: uniqueId, // ID estável baseado em conteúdo
          title: translatedTitle,
          summary: translatedSummary,
          source: isGoogleAlert ? 'Google Alerta' : 'ScienceDaily',
          url: link,
          date: date,
          imageUrl: _extractImage(entry) ?? '',
        ));
      }
      
      return articles;
      
    } catch (e, stack) {
      debugPrint('Erro no feed ($url): $e');
      if (kDebugMode) debugPrint("$stack");
      return [];
    }
  }

  // Cache simples de tradução (evita re-traduzir mesmas frases)
  final Map<String, String> _translationCache = {};
  
  Future<String> _translateWithCache(GoogleTranslator translator, String text) async {
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

  DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      try {
        return HttpDate.parse(dateString);
      } catch (_) {
        // Tenta formatos comuns de RSS
        final formats = [
          RegExp(r'(\d{1,2})\s+(\w+)\s+(\d{4})'), // 15 Jan 2026
          RegExp(r'(\w+),\s+(\d{1,2})\s+(\w+)'), // Tue, 15 Jan
        ];
        // Simplificado: retorna now se falhar
        return DateTime.now().subtract(const Duration(days: 1));
      }
    }
  }

  String _removeHtmlTags(String html) {
    if (html.isEmpty) return '';
    return html
      .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .trim();
  }

  String? _extractImage(XmlElement entry) {
    // Tenta extrair imagem de media:content ou enclosure
    final media = entry.findElements('media:content').firstOrNull ??
                  entry.findElements('enclosure').firstOrNull;
    return media?.getAttribute('url');
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}