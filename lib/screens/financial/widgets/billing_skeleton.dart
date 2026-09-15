import 'package:flutter/material.dart';

/// Placeholder pulsante para o bloco de billing do pacote.
///
/// Mesmas dimensões aproximadas do conteúdo final para o card não
/// mudar de altura quando o cálculo resolver (sem "pulo" de layout).
class BillingSkeleton extends StatefulWidget {
  const BillingSkeleton({super.key});

  @override
  State<BillingSkeleton> createState() => _BillingSkeletonState();
}

class _BillingSkeletonState extends State<BillingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final dx = (_ctrl.value * 2 - 0.5) * bounds.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE3D9F5),
                Color(0xFFF4EFFC),
                Color(0xFFE3D9F5),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(dx / bounds.width),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 92,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 64,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
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
    return Container(
      width: 180,
      height: 13,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7FA),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slide;
  const _SlidingGradientTransform(this.slide);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slide, 0.0, 0.0);
  }
}
