---
title: Agenda Manager
tags:
  - nexosaude
  - brain
  - screens
name: screen-agenda-manager
description: Grade semanal de agendamentos com finalização (Realizado/Falta/Atestado), encaixe e cancelamento.
---

# AgendaManagerScreen

`lib/screens/agenda/agenda_manager_screen.dart` (+ `agenda_cell_factory.dart`)

## O que é

Grade semanal (6 dias × slots 30min) lendo `appointments` via `getByDateRange`.
Filtro por dentista; dentista só vê o próprio.

## Quando usar

Ver/editar/cancelar/finalizar atendimento; célula vazia cria; long-press exclui.

## Fluxos

- Célula vazia → `AgendaCellFactory.openForm` (psico: form de pacote; dental: `AgendaForm` com pré-preenchimento).
- Ocupada → bottom sheet: editar, encaixe (máx 2), ver prontuário, finalizar, cancelar (soft) ou excluir (hard, `delete`).
- Finalizar → dialog Realizado (exige descrição; dental tem dropdown de plano/procedimento, **psico não — usa o vínculo do pacote automaticamente**) / Não Compareceu (motivo + **Apresentou Atestado**); grava `attendanceStatus`, `hasMedicalCertificate` e lança `clinical_records`.

## Gotchas

- `value` de `DropdownButtonFormField` depreciado → `initialValue`; `Radio groupValue/onChanged` → `RadioGroup`.
- Slots derivam de `durationMinutes` (30min base); bloqueios e cancelados têm render próprio (cenários A/B/C em `_buildCell`).
- Nome na célula (`_buildCellLabel`): até 2 linhas + `FittedBox.scaleDown` como rede (linha da grade tem 32px fixos; celular estreito não estoura).
- Carregamento: `AgendaSkeleton` (shimmer, `screens/agenda/agenda_skeleton.dart`) enquanto `waiting`; erro explícito, sem loader infinito. Shimmer compartilhado em `widgets/shimmer_box.dart` (também usado pelo `BillingSkeleton`).
- Filtro de dentista é assíncrono (`_checkRoleAndFetchDentists`): a grade segura no skeleton enquanto `_isLoadingDentists` p/ não exibir tudo sem filtro e trocar depois.
- Filtro de profissional: campo fino em largura total (`isDense`, padding vertical 4).

## Atualizações (web-designer + portal)

- Cache mensal deslizante (`MonthAgendaCache`): janela anterior/atual/próxima; semana em cache = zero leitura. Ver [[care-day]].
- Bloqueio/desbloqueio atualiza `portal_slots` via `adjustSlots` (1 escrita). Ver [[portal-mirror]].
- Menu "Decidir remarcação" abre [[remarcar-dialog]].

## Alternativa visual para avaliação (30/10/2026)

- Branch `feat/agenda-clinical-dark`: `clinical_agenda_view.dart` recebe a lista do mesmo cache, já filtrada por profissional, e delega ações à agenda existente.
- Proposta inicial de tema escuro local à Agenda; a evolução posterior da branch adicionou suporte ao tema claro/escuro global via `ThemeController`/`AppColors.isDark`. Desktop semanal/diário e mobile diário abaixo de 768px com faixa de sete dias.
- `--dart-define=AGENDA_CLINICAL_DARK=false` restaura a apresentação anterior para comparação.
- Contagem exclui cancelados/bloqueios; sem percentual fictício de ocupação. Os estados e intervalos dos dados continuam visíveis.
- Teste manual e limites: `docs/design/agenda/TESTE.md`. Expandir o visual para o restante do sistema somente após avaliação do usuário.


## Paridade funcional da alternativa

- Base da PR: `nova-audit`, preservando diretório mínimo, segurança e os fluxos existentes.
- `UserService.watchAgendaProfessionals(clinicId)` lê apenas `clinics/{clinicId}/members`, em tempo real. `agenda_professionals.dart` filtra membros ativos owner/dentista/psicólogo e normaliza aliases; recepção não é profissional de atendimento.
- `AgendaProfessionalSelector` usa membros reais, avatar por iniciais e contagem. Gestão alterna; dentistas/psicólogos ficam no próprio UID. Mudança de vínculo/status invalida seleção antiga. Erro e lista vazia são explícitos, com nova tentativa.
- Ações da agenda clássica e da alternativa compartilham seleção/filtragem. Sem profissional ativo não se cria/bloqueia; a Gestão usa o dia selecionado na visão diária.
- `AgendaCellFactory.formForSlot` passa data/hora e profissional aos dois formulários. Contratos/sessões de psicologia preservam `dentistId`; ocupação dental filtra o profissional selecionado.
- Legados sem profissional seguem visíveis para a gestão; não atribuir automaticamente por nome ou pelo primeiro profissional.


## Temas claro e escuro — PR #2

A apresentação clínica respeita `ThemeController`/`AppColors.isDark`, incluindo Agenda, Atendimento, menu e ficha do paciente. O seletor de sol/lua fica abaixo de Sair no rodapé do menu lateral (desktop e drawer mobile); usa a mesma preferência de Gestão → Configurações → Aparência e sincroniza por usuário. Superfícies, textos, campos, destaques e botões têm cores para ambos os modos. Trocar o tema não troca a aba nem recria o formulário ou a leitura do paciente. O logo original é preservado.

## Atualização visual — 03/11/2026
Referência screen(10).png/code(7).html/DESIGN(7).md: barra compacta com Dia/Semana, Mês (abre calendário para escolher uma data e entrar no dia), profissional real, período/anterior/próxima/Hoje e busca local por paciente/procedimento. Cabeçalhos redundantes removidos; cartões compactos com faixa de status e tipografia ampliada. Grade de segunda a sábado, expandida para domingo quando há agendamentos; domingo também acessível na faixa diária/calendário. Mantém horário ampliado dinamicamente, durações e faixas de encaixe, bloqueios/cancelamentos, cache e ações originais. Claro/escuro e mobile diário preservados. Busca só filtra exibição, sem modificar registros ou contagem do seletor. Logo/menu/identidade no rodapé aprovados preservados; não adiciona sino/perfil duplicados do mockup.

Validação: diff --check aprovado; testes de regressão existentes preservados, novos cenários para busca/calendário/domingos adicionados. Flutter/build/renderização não executados nesta revisão por SDK ausente. Conferir em 390/768/1200/1600 px com conta autorizada antes de publicar.

## Integridade do cancelamento — auditoria 03/11/2026

O botão **Cancelar Agendamento** abre `_showCancellationDialog`, coleta origem e motivo e primeiro atualiza `appointments/{id}` com `status='Cancelado'`, `cancelledBy`, `cancellationReason`, `cancellationSource` e `cancelledAt`. Em seguida faz `_clinicalRecordService.add` com `procedureName='Cancelamento de Consulta'`. **São duas operações assíncronas independentes**; se a segunda falhar, o status pode mudar sem registro clínico correspondente. O método `AppointmentService.cancel(id)` não executa esta gravação clínica. Portanto, nunca garantir que todo cancelamento tenha anotação no prontuário sem confirmar qual fluxo foi usado.

A variante `clinical_records_view.dart` exibe cancelamentos reconhecidos, inclusive legados cujo título contém “cancelamento”, sem atribuir um diagnóstico ou deduzir autoria profissional. Testes pendentes: cancelar pela UI, cancelar por serviço, repetição e falha parcial (antes de publicar). Ver [[agenda]], [[clinical]], [[auditoria-codigo-2026-11-03]].

## Tags por procedimento — 03/11/2026
Formulário odontológico e painel de ações renovados conforme referências 215608/215612. Tags individuais por paciente/orçamento/linha, escolhidas no agendamento e revisadas na finalização, com conclusão por Tag e evolução atômica. Oito por encontro; financeiro não é quitado por conclusão clínica. Cancelar/desmarcar não apaga Tags. Psicologia/pacotes/atestados mantidos. Modelo, migração DRY-RUN e roteiro: docs/design/agenda/TAGS.md.
