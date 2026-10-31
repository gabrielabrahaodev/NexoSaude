import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/agenda_professionals.dart';
import 'clinical_agenda_view.dart';

class AgendaProfessionalSelector extends StatelessWidget {
  const AgendaProfessionalSelector({
    super.key,
    required this.professionals,
    required this.selectedId,
    required this.onChanged,
    required this.onRetry,
    this.loading = false,
    this.error,
    this.enabled = true,
    this.appointmentCount = 0,
  });
  final List<UserModel> professionals;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;
  final bool loading;
  final String? error;
  final bool enabled;
  final int appointmentCount;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Row(
        children: [
          Icon(Icons.error_outline, color: ClinicalAgendaStyle.danger),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Não foi possível carregar os profissionais da clínica.',
            ),
          ),
          IconButton(
            tooltip: 'Tentar novamente',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      );
    }
    if (loading) {
      return const SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Carregando profissionais…')),
          ],
        ),
      );
    }
    if (professionals.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.person_off_outlined),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Nenhum profissional ativo vinculado à clínica.'),
          ),
          IconButton(
            tooltip: 'Atualizar profissionais',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      );
    }
    final selected = professionals.where((u) => u.id == selectedId).firstOrNull;
    final name = selected?.name ?? '';
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first)
        .join();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ClinicalAgendaStyle.elevated.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ClinicalAgendaStyle.blue,
            foregroundColor: ClinicalAgendaStyle.onBlue,
            child: Text(initials.isEmpty ? '?' : initials),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('agenda-professional'),
                value: selectedId,
                isExpanded: true,
                menuMaxHeight: 360,
                icon: enabled
                    ? const Icon(Icons.expand_more)
                    : const SizedBox.shrink(),
                onChanged: enabled ? onChanged : null,
                selectedItemBuilder: (context) => professionals
                    .map(
                      (u) => Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.name.isEmpty ? 'Profissional' : u.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${agendaProfessionalRoleLabel(u.role)} • $appointmentCount consultas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ClinicalAgendaStyle.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                items: professionals
                    .map(
                      (u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(
                          '${u.name.isEmpty ? 'Profissional' : u.name} — ${agendaProfessionalRoleLabel(u.role)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
