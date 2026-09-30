---
title: Psychology Kanban
tags:
  - nexosaude
  - brain
  - screens
name: screen-psychology-kanban
description: Fluxo terapêutico (kanban) das agendas de psicologia.
---

# PsychologyKanbanBoard

`lib/screens/patients/psychology/psychology_kanban_board.dart`

## O que é

Kanban por estágio do acompanhamento (`_CheckItem` por card), visível só na psico (menu 11).
Colunas: Prospecto → Acompanhamento → Alta-Manutenção (gravados `lead/active/discharged` em `patients.status`; arrastar grava direto). Enum + labels em `models/therapeutic_status.dart`.

## Quando usar

Mudar estágio, checklist de sessão.

## Gotchas

- Drag callbacks antigos (`onWillAccept/onAccept` → versões `WithDetails`).
- `withOpacity` aqui (e não `withValues`) — migrar ao tocar.

## Atualizações

- Colunas filtram `clinicId` no server (índice status+clinicId); antes vazava entre clínicas. Ver [[portal-mirror]].

## Ver também

- [[screens/clinical/psychology-schedule|psychology-schedule]] — contratos que o kanban acompanha
- [[psychology-packages]] — billing por presença
- [[screens/clinical/patient-details|patient-details]] — ficha dos pacientes em fluxo
