---
name: screen-psychology-schedule
description: Contrato de pacote/sessão de psicologia — lista e formulário com geração em lote.
---

# PsychologySchedule (Form)

`lib/screens/psychology/psychology_schedule_form_screen.dart`

## O que é

Form que cria contrato, plano, appointments e financials num batch só.
Aberto pelas células vazias da agenda (psico) via `AgendaCellFactory`.
(A tela de lista `Agendas Psicologia` foi removida do menu; contratos ativos
se acompanham pela agenda + kanban.)

## Quando usar

Novo pacote, recorrência, valores, terceiro pagador.

## Fluxos

- Form trava data/dia/hora quando vem da agenda (`preSelected*`).
- `_generateAppointments`: pacote gera recorrência até 31/12; **avulsa gera 1 sessão só na data selecionada** → plano + financeiro (pacote: mensal com `billingKind`/`monthlyPeriod`, vence dia 10 seguinte; avulso: 1 conta `1/1`, +7 dias) + appointments com `scheduleId/planId/monthlyPeriod`.
- Edição (`update`) **não regenera** nada — só o `add` gera.

## Gotchas

- Ver spec completa em `modules/psychology-packages.md`.
