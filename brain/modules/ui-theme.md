---
name: ui-theme-module
description: Tema global, estilos e widgets compartilhados (cards, kanban, contexto do paciente).
---

# UI / Tema

## O que é

`AppColors`/`AppTextStyles`/`ThemeData` + widgets reutilizáveis entre telas.

## Quando usar

Nova tela, card, lista kanban, atalho de ação.

## Arquivos-chave

- `lib/ui/app_theme.dart` (`background` depreciado → usar `surface`), `lib/ui/odontogram/tooth_widget.dart`, `lib/utils/app_constants.dart`
- `lib/widgets/appointment_cards.dart` (`AppointmentActionCard`, `SimpleAppointmentCard`), `lab_kanban_board.dart`, `patient_smart_context_card.dart`, `quick_action_button.dart`

## Fluxos

- Telas usam `AppColors.background/surface/textPrimary` e `AppTextStyles` — não hardcodar cores.
- `PatientSmartContextCard` resume o paciente (inclui risco) no topo de detalhes.

## Regras / Gotchas

- `withOpacity` depreciado em todo o projeto → usar `withValues(alpha:)`.
- `LabKanbanBoard` tem import duplicado e drag callbacks antigos (`onWillAccept/onAccept` → `WithDetails`).
