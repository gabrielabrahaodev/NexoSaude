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
- Cancelados não são sessões faturáveis no fluxo por presença. **Cancelamento solicitado pelo paciente** pode contar como falta no perfil de risco (`patient_service.dart`); não documentar que todo cancelamento sai do risco. Pendente (`Aguardando Confirmação`) não entra no cálculo por presença.
- Disponibilidade: slots de 30min a partir de `durationMinutes`.
- Células: nome em 12px negrito adaptativo (`textPrimary`: branco no escuro); borda/ícone mantêm a cor do status; fundo de bloqueio escurecido no dark.
- Bloqueio por intervalo: 1 doc (`BLOCKED_SLOT`, `date`+duração); paciente primeiro, fusão, idempotência. Ver `services/block_interval.dart`.

## Ver também

- [[agenda-manager]] — grade semanal (lê este domínio)
- [[agenda-form]] — criação/edição com trava de choque
- [[care-day]] — executa os agendamentos do dia
- [[portal-mirror]] — bloqueios viram slots livres/removidos

## Auditoria de cancelamento — 03/11/2026 (variante clínica)

O diálogo `_showCancellationDialog`, em `lib/screens/agenda/agenda_manager_screen.dart`, faz **duas gravações distintas**: primeiro atualiza `appointments/{id}` para `Cancelado` com `cancelledBy`, `cancellationReason`, `cancellationSource` e `cancelledAt`; depois cria um `clinical_records` com `procedureName = 'Cancelamento de Consulta'`, descrição do motivo, origem e operador. **Não há atomicidade garantida entre elas**. O método genérico `AppointmentService.cancel(id)` é outro caminho: altera o agendamento e o espelho/slots, mas não cria registro clínico. Não concluir que todos os cancelamentos, de qualquer origem, aparecem no prontuário.

**Pendente (não corrigido nesta documentação):** revisar contrato único de cancelamento, tratar falha da segunda gravação, idempotência e isolamento por clínica, e testar cancelamento repetido. O prontuário da variante clínica usa `ClinicalRecordsView` para classificar cancelamentos por campos/títulos efetivamente registrados. Ver [[auditoria-codigo-2026-11-03]] e [[patient-tabs]].

## Remarcação — validação de intervalo

`RemarcacaoService.approve` revalida no servidor todos os blocos de 30 minutos tocados por `durationMinutes`, inclusive início fora da grade e virada de dia, no escopo de `dentistId` e excluindo apenas o próprio agendamento. O espelho público permanece consultivo. A validação prévia não constitui um bloqueio transacional de reservas concorrentes.
