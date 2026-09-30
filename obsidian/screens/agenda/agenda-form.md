---
title: Agenda Form
tags:
  - nexosaude
  - brain
  - screens
name: screen-agenda-form
description: Formulário de agendamento dental com verificação de disponibilidade e seleção de paciente.
type: screen
status: stable
updated: 2026-09-30
---

# AgendaFormScreen

`lib/screens/agenda/agenda_form_screen.dart`

## O que é

Criação/edição de `appointments` dental (`editAppointmentId` + `initialData` quando edição).

## Quando usar

Novo agendamento, reagendar, checar choque de horário.

## Fluxos

- Checa `getBusySlots` (exclui o próprio id na edição) antes de salvar.
- Busca paciente por nome (`patients`) para vincular `patientId/patientName` — autocomplete com **debounce 350ms** (1 query por pausa, mín 2 letras).
- Cadastro rápido (`_showNewPatientModal`) com checkbox LGPD (sem aceite, sem token).
- Status inicial: `Aguardando Confirmação`.

## Gotchas

- Campos `_selectedTimes/_forcedAvailableTimes` deveriam ser `final` (lint).
- Contexto após async gap: conferir `mounted` antes de SnackBar/Navigator.

## Ver também

- [[screens/agenda/agenda-manager|agenda-manager]] — grade que abre este form
- [[screens/clinical/create-patient|create-patient]] — cadastro completo (o form tem cadastro rápido)
- [[screens/clinical/patient-list|patient-list]] — busca alternativa de paciente
