import 'package:flutter/material.dart';

/// Usa o arquivo original da marca, sem redesenhar ou recolorir o logotipo.
class ClinicalAgendaBrand extends StatelessWidget {
  const ClinicalAgendaBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Center(
    child: Image.asset(
      'assets/logo.png',
      width: compact ? 130 : 230,
      height: compact ? 52 : 110,
      fit: BoxFit.contain,
      semanticLabel: 'NexoSaúde',
    ),
  );
}
