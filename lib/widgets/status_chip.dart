import 'package:flutter/material.dart';

/// Selo padrão do app: texto branco curto sobre cor cheia.
/// Espaçamentos parametrizados para migração sem mudar nenhum pixel
/// (novos usos: prefira o padrão 8/3/9).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final double horizontal;
  final double vertical;
  final double fontSize;
  final double radius;
  final bool bold;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.horizontal = 8,
    this.vertical = 3,
    this.fontSize = 9,
    this.radius = 10,
    this.bold = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(radius)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.w400),
      ),
    );
  }
}
