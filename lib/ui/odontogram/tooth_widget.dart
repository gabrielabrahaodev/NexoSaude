import 'package:flutter/material.dart';
import '../../../models/tooth_model.dart';

class ToothWidget extends StatelessWidget {
  final ToothModel tooth;
  final Function(ToothModel, ToothFace) onFaceTap; 
  final double size;

  const ToothWidget({
    super.key,
    required this.tooth,
    required this.onFaceTap,
    this.size = 40, // Aumentei um pouco para caber a raiz
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tooth.isUpper) _buildLabel(),
        
        SizedBox(
          width: size,
          height: size * 1.3, // Altura maior para acomodar raiz + coroa
          child: GestureDetector(
            onTapUp: (details) {
              _handleTap(details.localPosition, size, size * 1.3);
            },
            child: CustomPaint(
              size: Size(size, size * 1.3),
              painter: _GeometricToothPainter(
                facesStatus: tooth.facesStatus,
                isMissing: tooth.isMissing,
                isUpper: tooth.isUpper,
              ),
            ),
          ),
        ),

        if (!tooth.isUpper) _buildLabel(),
      ],
    );
  }

  void _handleTap(Offset position, double w, double h) {
    // Definições de proporção
    double rootHeight = h * 0.30; // 30% para raiz
    double crownHeight = h * 0.70; // 70% para coroa
    
    // Ajuste de coordenadas dependendo se é superior ou inferior
    bool hitRoot = false;
    double localY = position.dy;

    if (tooth.isUpper) {
      // Superior: Raiz está no topo (0 a 30%)
      if (position.dy < rootHeight) hitRoot = true;
      else localY = position.dy - rootHeight; // Normaliza Y para cálculo das faces
    } else {
      // Inferior: Raiz está na base (70% a 100%)
      if (position.dy > crownHeight) hitRoot = true;
      // localY já está correto para coroa (0 a 70%)
    }

    if (hitRoot) {
      onFaceTap(tooth, ToothFace.root);
      return;
    }

    // --- CÁLCULO DAS FACES (Cópia da lógica anterior ajustada) ---
    // Precisamos considerar que a coroa é um quadrado dentro da área restante
    double size = w; // A largura é o limitante
    
    double centerRatio = 0.35;
    double centerStart = size * (0.5 - centerRatio / 2);
    double centerEnd = size * (0.5 + centerRatio / 2);

    // Oclusal
    if (position.dx > centerStart && position.dx < centerEnd &&
        localY > centerStart && localY < centerEnd) {
      onFaceTap(tooth, ToothFace.occlusal);
      return;
    }

    // Diagonais
    bool topRight = localY < position.dx;
    bool topLeft = localY < (size - position.dx);

    if (topLeft && topRight) {
      onFaceTap(tooth, ToothFace.vestibular);
    } else if (!topLeft && !topRight) {
      onFaceTap(tooth, ToothFace.lingual);
    } else if (topLeft && !topRight) {
      onFaceTap(tooth, ToothFace.mesial);
    } else {
      onFaceTap(tooth, ToothFace.distal);
    }
  }

  Widget _buildLabel() => Text(
    "${tooth.id}",
    style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.bold),
  );
}

class _GeometricToothPainter extends CustomPainter {
  final Map<String, String> facesStatus;
  final bool isMissing;
  final bool isUpper;

  _GeometricToothPainter({required this.facesStatus, required this.isMissing, required this.isUpper});

  Color _getColor(String? status) {
    switch (status) {
      // Status Gerais
      case 'issue': return Colors.redAccent; 
      case 'restored': return Colors.blue; 
      case 'planned': return Colors.orange;
      case 'missing': return Colors.black87;
      
      // Status de Raiz
      case 'endo_planned': return Colors.pinkAccent; // Endo a fazer
      case 'endo_done': return Colors.black; // Endo feita
      case 'implant_planned': return Colors.purpleAccent; // Implante a fazer
      case 'implant_done': return Colors.grey; // Implante feito (Pino titânio)
      
      // Status de Coroa
      case 'crown_planned': return Colors.orangeAccent;
      case 'crown_done': return Colors.teal; // Coroa Porcelana/Metal

      default: return Colors.white; 
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final border = Paint()..style = PaintingStyle.stroke..color = Colors.grey.shade400..strokeWidth = 1.0;

    double w = size.width;
    double h = size.height;
    double rootH = h * 0.30;
    
    // Coordenadas base
    double crownStartY = isUpper ? rootH : 0;
    
    // --- DESENHO DA RAIZ ---
    Path rootPath = Path();
    if (isUpper) {
      // Triângulo apontando para cima
      rootPath.moveTo(0, rootH);
      rootPath.lineTo(w, rootH);
      rootPath.lineTo(w * 0.5, 0); // Ponta
      rootPath.close();
    } else {
      // Triângulo apontando para baixo
      rootPath.moveTo(0, h - rootH);
      rootPath.lineTo(w, h - rootH);
      rootPath.lineTo(w * 0.5, h); // Ponta
      rootPath.close();
    }
    
    paint.color = _getColor(facesStatus[ToothFace.root.name]);
    canvas.drawPath(rootPath, paint);
    canvas.drawPath(rootPath, border);

    // Se extraído, faz X na raiz também
    if (isMissing) {
      paint.color = Colors.grey.withValues(alpha: 0.3);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
      final xPaint = Paint()..color = Colors.red..strokeWidth = 2;
      canvas.drawLine(Offset(0, 0), Offset(w, h), xPaint);
      canvas.drawLine(Offset(w, 0), Offset(0, h), xPaint);
      return; 
    }

    // --- DESENHO DA COROA (Quadrado dividido) ---
    // Transladamos o canvas para desenhar a coroa no lugar certo
    canvas.save();
    canvas.translate(0, crownStartY);
    
    // Usamos um quadrado perfeito para a coroa
    double cSize = w; 
    double cS = cSize * 0.33;
    double cE = cSize * 0.67;

    // 1. Oclusal (Centro)
    paint.color = _getColor(facesStatus[ToothFace.occlusal.name]);
    Rect centerRect = Rect.fromLTRB(cS, cS, cE, cE);
    canvas.drawRect(centerRect, paint);
    canvas.drawRect(centerRect, border);

    // 2. Vestibular (Topo do quadrado)
    Path pathV = Path()..moveTo(0, 0)..lineTo(cSize, 0)..lineTo(cE, cS)..lineTo(cS, cS)..close();
    paint.color = _getColor(facesStatus[ToothFace.vestibular.name]);
    canvas.drawPath(pathV, paint);
    canvas.drawPath(pathV, border);

    // 3. Lingual (Baixo do quadrado)
    Path pathL = Path()..moveTo(0, cSize)..lineTo(cSize, cSize)..lineTo(cE, cE)..lineTo(cS, cE)..close();
    paint.color = _getColor(facesStatus[ToothFace.lingual.name]);
    canvas.drawPath(pathL, paint);
    canvas.drawPath(pathL, border);

    // 4. Mesial (Esquerda)
    Path pathM = Path()..moveTo(0, 0)..lineTo(0, cSize)..lineTo(cS, cE)..lineTo(cS, cS)..close();
    paint.color = _getColor(facesStatus[ToothFace.mesial.name]);
    canvas.drawPath(pathM, paint);
    canvas.drawPath(pathM, border);

    // 5. Distal (Direita)
    Path pathD = Path()..moveTo(cSize, 0)..lineTo(cSize, cSize)..lineTo(cE, cE)..lineTo(cE, cS)..close();
    paint.color = _getColor(facesStatus[ToothFace.distal.name]);
    canvas.drawPath(pathD, paint);
    canvas.drawPath(pathD, border);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GeometricToothPainter oldDelegate) => true;
}