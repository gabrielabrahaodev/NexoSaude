---
title: Ui Theme
tags:
  - nexosaude
  - brain
  - modules
name: ui-theme-module
description: Tema global, estilos e widgets compartilhados (cards, kanban, contexto do paciente).
---

# UI / Tema

## O que é

`AppColors`/`AppTextStyles`/`ThemeData` + widgets reutilizáveis entre telas.

## Quando usar

Nova tela, card, lista kanban, atalho de ação.

## Arquivos-chave

- `lib/ui/app_theme.dart` (`AppColors` adaptativo claro/escuro via `ThemeController`; `primary/accent/danger` seguem const), `lib/ui/odontogram/tooth_widget.dart`, `lib/utils/display.dart` (helpers puros: `parseBRL`, `daysAgoLabel`, `slotCardColor`, `chargeBadgeColor`)
- `lib/widgets/appointment_cards.dart` (`AppointmentActionCard`, `SimpleAppointmentCard`), `lab_kanban_board.dart`, `patient_smart_context_card.dart`, `quick_action_button.dart`

## Fluxos

- Telas usam `AppColors.background/surface/textPrimary` e `AppTextStyles` — não hardcodar cores.
- `PatientSmartContextCard` resume o paciente (inclui risco) no topo de detalhes.

## Regras / Gotchas

- `withOpacity` depreciado em todo o projeto → usar `withValues(alpha:)`.
- `LabKanbanBoard` tem import duplicado e drag callbacks antigos (`onWillAccept/onAccept` → `WithDetails`).

## Atualizações (web-designer)

- Varredura dark completa; `StatusChip` único; datas/moeda/toast em [[ui-consistency]].

## Ver também

- [[main-dashboard]] — shell que aplica o tema
- [[agenda-manager]] — células com tipo adaptativo
- [[care-day]] — cards translúcidos + ficha em modal


## Temas claro e escuro — PR #2

A apresentação clínica respeita `ThemeController`/`AppColors.isDark`, incluindo Agenda, Atendimento, menu e ficha do paciente. O seletor de sol/lua fica abaixo de Sair no rodapé do menu lateral (desktop e drawer mobile); usa a mesma preferência de Gestão → Configurações → Aparência e sincroniza por usuário. Superfícies, textos, campos, destaques e botões têm cores para ambos os modos. Trocar o tema não troca a aba nem recria o formulário ou a leitura do paciente. O logo original é preservado.

`AGENDA_CLINICAL_DARK` continua sendo a flag da nova apresentação, não uma imposição do modo escuro. Os temas locais registram dependência do tema herdado (`forContext`) para atualizar telas já montadas sem recriar seus estados.
