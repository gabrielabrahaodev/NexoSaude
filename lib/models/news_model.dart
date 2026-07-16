class OrthoArticle {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String url;
  final DateTime date;
  final String imageUrl;

  OrthoArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.date,
    this.imageUrl = '',
  });
}