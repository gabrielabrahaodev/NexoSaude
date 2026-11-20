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

## Ocupação dos horários

O formulário acompanha os agendamentos da unidade/profissional em tempo real, incluindo a duração integral e sobreposições parciais (ex.: 09:15–10:00 ocupa 09:00 e 09:30). Cancelados liberam o horário; na edição apenas o próprio agendamento é excluído. Legados sem profissional bloqueiam conservadoramente. Ocupados aparecem em vermelho, com texto e tooltip, e não podem ser selecionados. A seleção inicial não tem exceção para ocupação.

Antes de salvar há nova consulta ao servidor; se algum horário tiver sido ocupado, a seleção conflitante é removida e é solicitado outro horário. Falha de consulta bloqueia salvar. Isso reduz conflitos, mas não é um lock transacional entre dois operadores gravando exatamente ao mesmo tempo. Nenhuma alteração de Rules ou coleção foi necessária.


## Auditoria de integridade em andamento

Consulte `docs/design/agenda/AUDITORIA-INTEGRIDADE.md`. Exclusões de contratos/histórico estão bloqueadas conservadoramente. Catálogo usa desativação lógica. Locks transacionais, reconciliação do portal e invariantes completas das Rules continuam pendentes. Não publicar esta revisão isoladamente.


## Encaixe — limite de duas consultas simultâneas

No formulário odontológico, 0 consultas ativas libera horário, 1 permite encaixe (identificado no botão), 2 ou mais bloqueiam. Conta o pico simultâneo em cada intervalo, preserva unidade/profissional e desconsidera cancelados e o próprio agendamento na edição. Escolher intervalo com uma consulta marca isFitIn automaticamente. A consulta ao servidor repete a verificação antes de salvar. A garantia transacional contra dois clientes concorrentes continua pendente conforme auditoria.
