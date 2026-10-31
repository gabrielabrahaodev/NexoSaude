import 'package:flutter/material.dart';

/// Keeps list and detail inside the dashboard's existing content region.
/// The clinic key supplied by the shell isolates selection between clinics.
class PatientWorkspace extends StatefulWidget {
  const PatientWorkspace({
    super.key,
    required this.listBuilder,
    required this.detailBuilder,
  });
  final Widget Function(BuildContext, void Function(String, String))
  listBuilder;
  final Widget Function(BuildContext, String, String, VoidCallback)
  detailBuilder;
  @override
  State<PatientWorkspace> createState() => _PatientWorkspaceState();
}

class _PatientWorkspaceState extends State<PatientWorkspace> {
  ({String id, String name})? _selected;
  void _close() => setState(() => _selected = null);
  @override
  Widget build(BuildContext context) {
    final patient = _selected;
    return PopScope(
      canPop: patient == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selected != null) _close();
      },
      child: IndexedStack(
        index: patient == null ? 0 : 1,
        children: [
          widget.listBuilder(
            context,
            (id, name) => setState(() => _selected = (id: id, name: name)),
          ),
          if (patient != null)
            KeyedSubtree(
              key: ValueKey(patient.id),
              child: widget.detailBuilder(
                context,
                patient.id,
                patient.name,
                _close,
              ),
            ),
        ],
      ),
    );
  }
}
