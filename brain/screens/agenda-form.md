---
name: screen-agenda-form
description: Formulário de agendamento dental com verificação de disponibilidade e seleção de paciente.
---

# AgendaFormScreen

`lib/screens/agenda/agenda_form_screen.dart`

## O que é

Criação/edição de `appointments` dental (`editAppointmentId` + `initialData` quando edição).

## Quando usar

Novo agendamento, reagendar, checar choque de horário.

## Fluxos

- Checa `getBusySlots` (exclui o próprio id na edição) antes de salvar.
- Busca paciente por nome (`patients`) para vincular `patientId/patientName`.
- Status inicial: `Aguardando Confirmação`.

## Gotchas

- Campos `_selectedTimes/_forcedAvailableTimes` deveriam ser `final` (lint).
- Contexto após async gap: conferir `mounted` antes de SnackBar/Navigator.
