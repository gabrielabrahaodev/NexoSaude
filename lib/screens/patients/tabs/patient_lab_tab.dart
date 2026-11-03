import 'package:flutter/material.dart';
import '../../../models/lab_order.dart';
import '../../../services/lab_service.dart';
import '../../../widgets/lab_kanban_board.dart';
import '../../lab/lab_order_dialog.dart';

class PatientLabTab extends StatefulWidget {
  const PatientLabTab({super.key, required this.patientId});
  final String patientId;
  @override
  State<PatientLabTab> createState() => _PatientLabTabState();
}

class _PatientLabTabState extends State<PatientLabTab> {
  late Stream<List<LabOrderModel>> _orders;
  bool _creating = false;
  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() => _orders = LabService().getByPatient(widget.patientId);
  @override
  void didUpdateWidget(covariant PatientLabTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) _watch();
  }

  Future<void> _newOrder() async {
    if (_creating) return;
    setState(() => _creating = true);
    await showLabOrderDialog(context, patientId: widget.patientId);
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<LabOrderModel>>(
    stream: _orders,
    builder: (context, snapshot) => LabKanbanBoard(
      orders: snapshot.data ?? [],
      onNew: _newOrder,
      creating: _creating,
      loading: !snapshot.hasData && !snapshot.hasError,
      error: snapshot.hasError
          ? 'Não foi possível carregar os pedidos. Verifique sua conexão e o acesso à unidade.'
          : null,
    ),
  );
}
