import 'package:flutter/material.dart';
import '../../models/lab_order.dart';
import '../../services/lab_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/lab_kanban_board.dart';
import 'lab_order_dialog.dart';

class ClinicLabScreen extends StatefulWidget {
  const ClinicLabScreen({super.key});
  @override
  State<ClinicLabScreen> createState() => _ClinicLabScreenState();
}

class _ClinicLabScreenState extends State<ClinicLabScreen> {
  late final Stream<List<LabOrderModel>> _orders;
  bool _creating = false;
  @override
  void initState() {
    super.initState();
    final clinic = SessionManager().currentClinicId;
    _orders = clinic == null
        ? const Stream.empty()
        : LabService().getByClinic(clinic);
  }

  Future<void> _newOrder() async {
    if (_creating) return;
    setState(() => _creating = true);
    await showLabOrderDialog(context);
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<LabOrderModel>>(
    stream: _orders,
    builder: (context, snapshot) => LabKanbanBoard(
      orders: snapshot.data ?? [],
      onNew: _newOrder,
      creating: _creating,
      showPatientName: true,
      loading: !snapshot.hasData && !snapshot.hasError,
      error: snapshot.hasError
          ? 'Não foi possível carregar os pedidos. Verifique sua conexão e o acesso à unidade.'
          : null,
    ),
  );
}
