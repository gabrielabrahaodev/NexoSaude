// ortho_news_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatar datas
import 'package:url_launcher/url_launcher.dart';
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
    setState(() {
      _newsFuture = _newsService.getLatestOrthoNews();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Paleta de cores suave para área médica
    final bgColor = Color(0xFFF5F7FA);
    final primaryColor = Color(0xFF0D47A1); // Azul Profundo

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ortodontia Science",
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              "Últimas atualizações científicas",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link')),
        );
      }
    }
  }

  // O Widget do Card Minimalista
  Widget _buildMinimalistCard(OrthoArticle article, BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final Uri uri = Uri.parse(article.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível abrir o link')),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho do Card (Fonte e Data)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      article.source.toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(article.date),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Título
              Text(
                article.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
              
              SizedBox(height: 10),
              
              // Resumo
              Text(
                article.summary,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 20),
              
              // Rodapé do Card (Link)
              Row(
                children: [
                  Text(
                    "Ler artigo completo",
                    style: TextStyle(
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF0D47A1)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}