import 'package:flutter/material.dart';
import '../../widgets/shimmer_box.dart';

/// Skeleton da grade semanal da agenda.
///
/// Imita o `Table` real (coluna de horas 45px + 6 dias flex) para a troca
/// shimmer → conteúdo não dar "pulo" de layout. Exibido enquanto o stream
/// de `appointments` não resolve (troca de semana/clínica/entrada).
class AgendaSkeleton extends StatelessWidget {
  /// Nº de linhas de horário simuladas.
  final int rows;

  const AgendaSkeleton({super.key, this.rows = 9});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Table(
          columnWidths: const {0: FixedColumnWidth(45)},
          defaultColumnWidth: const FlexColumnWidth(1),
          children: [
            // Cabeçalho dos dias
            TableRow(
              children: [
                const SizedBox(height: 44),
                ...List.generate(
                  6,
                  (_) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        ShimmerBox(width: 34, height: 10),
                        SizedBox(height: 5),
                        ShimmerBox(width: 20, height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Linhas de horário
            for (var r = 0; r < rows; r++)
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Center(child: ShimmerBox(width: 26, height: 9)),
                  ),
                  ...List.generate(
                    6,
                    (c) => Padding(
                      padding: const EdgeInsets.all(5),
                      child: ShimmerBox(
                        width: double.infinity,
                        // Algumas "consultas" fake p/ parecer grade real
                        height: (r * 7 + c * 13) % 4 == 0 ? 34 : 22,
                        radius: 8,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
