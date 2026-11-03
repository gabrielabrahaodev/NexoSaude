---
title: Agenda Form
tags:
  - nexosaude
  - brain
  - screens
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
- Busca paciente por nome (`patients`) para vincular `patientId/patientName` — autocomplete com **debounce 350ms** (1 query por pausa, mín 2 letras).
- Cadastro rápido (`_showNewPatientModal`) com checkbox LGPD (sem aceite, sem token).
- Status inicial: `Aguardando Confirmação`.

## Gotchas

- Campos `_selectedTimes/_forcedAvailableTimes` deveriam ser `final` (lint).
- Contexto após async gap: conferir `mounted` antes de SnackBar/Navigator.

## Ver também

- [[agenda-manager]] — grade que abre este form
- [[create-patient]] — cadastro completo (o form tem cadastro rápido)
- [[patient-list]] — busca alternativa de paciente


## Seleção de profissional

`agendaBookingProfessionalId` preserva a escolha da gestão e restringe dentistas/psicólogos ao próprio UID, incluindo aliases. A ocupação de horários respeita esse profissional, sem bloquear a agenda por uma consulta de outro membro. O `AgendaCellFactory` centraliza a abertura do formulário correto para a clínica.

## Formulário desktop 1080p

`ClinicalBookingView` concentra a apresentação: paciente, procedimento, Tags, calendário mensal e horários no mesmo cartão, observações e rodapé fixo. Espaçamento compacto em desktop, com ajuste adicional abaixo de 1040px de altura; telas pequenas mantêm rolagem. Tags extensas têm rolagem interna. Modo claro e escuro usam a mesma estrutura.

O teste de geometria cobre 1920×1000 e 1920×1080, nos dois temas e em mês com seis semanas. O WhatsApp permanece manual; sala, especialidade e número de prontuário só aparecem quando disponíveis no sistema. Disponibilidade e persistência continuam no AgendaFormScreen.
