import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/lab_order.dart';
import 'package:odonto_controle/services/lab_service.dart';
import 'package:odonto_controle/widgets/lab_kanban_board.dart';
import 'package:odonto_controle/screens/care/clinical_care_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

class _LabWrites extends Fake implements LabService {
  final writes = <({String id, String status, Map<String, dynamic> fields})>[];
  late void Function(String, Map<String, dynamic>) saved;
  @override
  Future<void> updateStatus(
    String id,
    String newStatus,
    Map<String, dynamic> additionalData,
  ) async {
    writes.add((id: id, status: newStatus, fields: additionalData));
    saved(newStatus, additionalData);
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final individual in [false, true]) {
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        testWidgets(
          'arraste real $kind / individual $individual / escuro $dark confirma e salva etapa',
          (tester) async {
            AppColors.isDark = dark;
            addTearDown(() => AppColors.isDark = false);
            final width = kind == PointerDeviceKind.mouse ? 1440.0 : 390.0;
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var order = LabOrderModel(
              id: 'internal-only-id',
              clinicId: 'c',
              patientId: 'p',
              patientName: 'Paciente real',
              description: 'Coroa',
              procedureName: 'Coroa',
              price: 120,
              relatedExpenseId: 'lab_internal-only-id',
              createdAt: DateTime(2026),
              status: 'pending_send',
            );
            final service = _LabWrites();
            await tester.pumpWidget(
              MaterialApp(
                theme: ClinicalCareStyle.theme,
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      service.saved = (status, fields) => setState(
                        () => order = LabOrderModel.fromMap(order.id, {
                          ...order.toMap(),
                          'status': status,
                          for (final e in fields.entries)
                            e.key: e.value is DateTime
                                ? Timestamp.fromDate(e.value as DateTime)
                                : e.value,
                        }),
                      );
                      return LabKanbanBoard(
                        orders: [order],
                        onNew: () {},
                        showPatientName: !individual,
                        service: service,
                      );
                    },
                  ),
                ),
              ),
            );
            expect(find.textContaining('OS ·'), findsNothing);
            expect(find.text('internal-only-id'), findsNothing);
            const steps = [
              ('sent', 'Confirmar Envio', 'sentDate'),
              ('pending_return', 'Previsão de Retorno', 'returnDate'),
              ('delivered', 'Confirmar Entrega', 'deliveredDate'),
            ];
            for (var i = 0; i < steps.length; i++) {
              final step = steps[i];
              final card = find.byKey(
                const ValueKey('lab-card-internal-only-id'),
              );
              await tester.ensureVisible(card);
              await tester.pumpAndSettle();
              final source = tester.getTopLeft(card) + const Offset(30, 75);
              final target = tester.getRect(
                find.byKey(ValueKey('lab-column-${step.$1}')),
              );
              final destination = Offset(
                math.min(target.right - 24, width - 24),
                target.top + 150,
              );
              final gesture = await tester.startGesture(source, kind: kind);
              // Mouse starts before the old timeout; touch deliberately holds.
              await tester.pump(
                Duration(
                  milliseconds: kind == PointerDeviceKind.mouse ? 20 : 350,
                ),
              );
              await gesture.moveTo(source + const Offset(14, 0));
              await tester.pump(const Duration(milliseconds: 20));
              await gesture.moveTo(destination);
              await tester.pump(const Duration(milliseconds: 20));
              await gesture.up();
              await tester.pumpAndSettle();
              expect(find.text(step.$2), findsOneWidget);
              expect(service.writes.length, i);
              await tester.tap(find.text('Confirmar Mover'));
              await tester.pumpAndSettle();
              expect(service.writes.length, i + 1);
              expect(service.writes.last.status, step.$1);
              expect(service.writes.last.fields[step.$3], isA<DateTime>());
              expect(
                find.descendant(
                  of: find.byKey(ValueKey('lab-column-${step.$1}')),
                  matching: card,
                ),
                findsOneWidget,
              );
              expect(order.relatedExpenseId, 'lab_internal-only-id');
              expect(order.price, 120);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
