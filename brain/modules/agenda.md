---
title: Agenda
tags:
  - nexosaude
  - brain
  - modules
name: agenda-module
description: Agendamentos, grade semanal, finalização com presença/atestado e repositório unificado dental+psico.
---

# Agenda

## O que é

Grade semanal de `appointments` + finalização (Realizado / Não Compareceu / Atestado).
`ScheduleRepository` oferece visão unificada de leitura sem fundir collections.

## Quando usar

Grade, criar/editar/cancelar agendamento, presença, encaixe, disponibilidade.

## Arquivos-chave

- `lib/services/appointment_service.dart` — `getByDateRange`, `getBusySlots`, `add/update/cancel`
- `lib/models/appointment_model.dart` — `scheduleId/planId/monthlyPeriod`, `attendanceStatus`, `hasMedicalCertificate`
- `lib/services/schedule_repository.dart` — `watchByClinic` combina dental + psico em `ScheduleItem`
- `lib/screens/agenda/agenda_cell_factory.dart` — decide qual form abre na célula vazia

## Fluxos

- Célula vazia → factory: psico abre `PsychologyScheduleForm`, dental abre `AgendaForm` com pré-preenchimento.
- Finalizar → `Realizado` exige evolução clínica; `Não Compareceu` mostra checkbox **Apresentou Atestado**; grava `attendanceStatus` + `hasMedicalCertificate` e lança no prontuário.
- Encaixe: máx 2 por horário; cancelamento é soft (`status Cancelado`).

## Regras / Gotchas

- `appointment` carrega `scheduleId/planId` — base do billing por presença; não remover.
- Cancelado sai do billing e do risco; pendente (`Aguardando Confirmação`) não entra no cálculo.
- Disponibilidade: slots de 30min a partir de `durationMinutes`.
