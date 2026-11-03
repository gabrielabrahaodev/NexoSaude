import 'package:flutter/material.dart';
import '../agenda/clinical_agenda_view.dart';

/// Shared footer for the desktop sidebar and mobile navigation drawer.
class ClinicalUserFooter extends StatelessWidget {
  const ClinicalUserFooter({
    super.key,
    required this.name,
    required this.subtitle,
    required this.dark,
    required this.onLogout,
    required this.onTheme,
  });
  final String name, subtitle;
  final bool dark;
  final VoidCallback onLogout, onTheme;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: ClinicalAgendaStyle.blue,
          child: Icon(
            Icons.person_outline,
            color: ClinicalAgendaStyle.onBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                subtitle,
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
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('clinical-logout'),
              tooltip: 'Sair',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 20),
            ),
            IconButton(
              key: const ValueKey('clinical-theme-toggle'),
              tooltip: dark ? 'Usar modo claro' : 'Usar modo escuro',
              onPressed: onTheme,
              icon: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
