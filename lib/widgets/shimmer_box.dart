import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// Shimmer genérico (brilho deslizante) p/ skeletons de carregamento.
///
/// Envolve o layout estático (filho) e anima um gradiente por cima —
/// mesma técnica do antigo `BillingSkeleton`, agora reutilizável.
/// Adapta claro/escuro via `AppColors`.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.isDark
        ? const [Color(0xFF2A2E35), Color(0xFF3A3F47), Color(0xFF2A2E35)]
        : const [Color(0xFFE3D9F5), Color(0xFFF4EFFC), Color(0xFFE3D9F5)];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final dx = (_ctrl.value * 2 - 0.5) * bounds.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: base,
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(dx / bounds.width),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Bloco placeholder (cor sólida adaptativa).
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.borderSoft,
        borderRadius: BorderRadius.circular(radius),
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
