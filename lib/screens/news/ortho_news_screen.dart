// ortho_news_screen.dart
import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import '../../services/session_manager.dart';
import '../../utils/external_link.dart';
import '../../models/news_model.dart';
import '../../services/news_service.dart';

class OrthoNewsScreen extends StatefulWidget {
  @override
  _OrthoNewsScreenState createState() => _OrthoNewsScreenState();
}

class _OrthoNewsScreenState extends State<OrthoNewsScreen> {
  final NewsService _newsService = NewsService();
  late Future<List<OrthoArticle>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  void _loadNews() {
    final clinicType = SessionManager().clinicType;
    setState(() {
      _newsFuture =
          _newsService.getLatestOrthoNews(clinicType: clinicType);
    });
  }

  String get _headerTitle =>
      SessionManager().clinicType == 'psychology'
          ? "Psi Science"
          : "Ortodontia Science";

  @override
  Widget build(BuildContext context) {
    // Paleta de cores suave para área médica
    final bgColor = AppColors.background;
    final primaryColor = Color(0xFF0D47A1); // Azul Profundo

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _headerTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              "Últimas atualizações científicas",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadNews,
          )
        ],
      ),
      body: FutureBuilder<List<OrthoArticle>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  SizedBox(height: 10),
                  Text("Erro ao carregar notícias."),
                  TextButton(onPressed: _loadNews, child: Text("Tentar novamente"))
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Nenhuma notícia encontrada hoje."));
          }

          final articles = snapshot.data!;

          return ListView.builder(
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final article = articles[index];
            // POR ISSO (Card simples funcional):
            return Card(
              key: ValueKey(article.id),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(
                  article.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  article.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${article.date.day}/${article.date.month}',
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () => _launchURL(article.url),
              ),
            );
          },
        );
        },
      ),
    );
  }

    // ADICIONE ESTE MÉTODO:
  Future<void> _launchURL(String url) async {
    if (url.isEmpty) return;
    final tab = openBlankTab();
    final ok = await openLinkSafe(tab, url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link')),
      );
    }
  }

}
