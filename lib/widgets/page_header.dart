import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ui/app_theme.dart';

/// Título minimalista padrão das telas (corpo): título 20 bold + subtítulo cinza.
class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PageTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// Seletor de mês padrão (pílula arredondada da tela de Relatórios):
/// chevrons nas pontas + "MÊS ANO" centralizado, com rótulos opcionais.
class MonthSelectorPill extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final String? labelAbove;
  final String? labelBelow;
  final TextStyle? labelBelowStyle;

  const MonthSelectorPill({
    super.key,
    required this.date,
    required this.onPrev,
    required this.onNext,
    this.labelAbove,
    this.labelBelow,
    this.labelBelowStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (labelAbove != null)
                Text(labelAbove!,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary)),
              Text(
                  DateFormat('MMMM yyyy', 'pt_BR')
                      .format(date)
                      .toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (labelBelow != null) ...[
                const SizedBox(height: 2),
                Text(labelBelow!,
                    style: labelBelowStyle ??
                        TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
              ],
            ],
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}
