import 'package:flutter/material.dart';
import 'clinical_agenda_view.dart';

class ClinicalAgendaBrand extends StatelessWidget {
  const ClinicalAgendaBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ClinicalAgendaStyle.elevated.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: CustomPaint(size: Size(24, 28), painter: _ToothPainter()),
            ),
            if (!compact)
              const Positioned(
                top: -4,
                right: -4,
                child: Icon(
                  Icons.emergency,
                  size: 14,
                  color: ClinicalAgendaStyle.blue,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Nexo'),
                  TextSpan(
                    text: 'Saúde',
                    style: const TextStyle(color: ClinicalAgendaStyle.teal),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            if (!compact)
              const Text(
                'CLÍNICA INTELIGENTE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .6,
                  color: ClinicalAgendaStyle.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _ToothPainter extends CustomPainter {
  const _ToothPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(12, 4)
      ..cubicTo(8, 4, 8, 1, 4, 2)
      ..cubicTo(-1, 3, 2, 12, 3, 18)
      ..cubicTo(4, 28, 7, 28, 9, 19)
      ..cubicTo(10, 15, 14, 15, 15, 19)
      ..cubicTo(17, 28, 20, 28, 21, 18)
      ..cubicTo(22, 12, 25, 3, 20, 2)
      ..cubicTo(16, 1, 16, 4, 12, 4);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF43E1BA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
