import 'package:flutter/material.dart';
import '../../../widgets/shimmer_box.dart';

/// Placeholder pulsante para o bloco de billing do pacote.
///
/// Mesmas dimensões aproximadas do conteúdo final para o card não
/// mudar de altura quando o cálculo resolver (sem "pulo" de layout).
class BillingSkeleton extends StatelessWidget {
  const BillingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ShimmerBox(width: 92, height: 20),
          SizedBox(height: 6),
          ShimmerBox(width: 64, height: 12),
        ],
      ),
    );
  }
}

/// Linha de placeholder para o detalhe do billing no subtítulo do card.
class BillingDetailSkeleton extends StatelessWidget {
  const BillingDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Padding(
        padding: EdgeInsets.only(top: 4),
        child: ShimmerBox(width: 180, height: 13),
      ),
    );
  }
}
