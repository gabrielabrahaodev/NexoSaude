---
name: screen-care-day
description: Meu dia com fichas distintas de odontologia e psicologia.
title: Care Day (Meu dia)
tags: [nexosaude, brain, screens, atendimento]
---

# Care Day (Meu dia)

`care_day_screen.dart` carrega consultas de hoje da clínica atual, excluindo cancelamentos e bloqueios. Dentistas/psicólogos veem a própria agenda; gestão e recepção podem filtrar profissional e status. Nomes vêm de `clinics/{clinicId}/members`, sem consulta geral de usuários. Confirmação em massa revalida cada consulta e informa falhas parciais.

## Ficha e persistência

Desktop com espaço suficiente usa lista cronológica e ficha lado a lado. No mobile a ficha abre em modal com fechamento explícito. `clinical_care_view.dart` contém apresentação; `care_visit_service.dart` centraliza gravações e valida clínica, paciente, operador e estado atual em transações.

- Salvar evolução grava o registro clínico sem finalizar nem registrar presença.
- Finalizar grava evolução e presença conjuntamente; sessões finalizadas ficam somente leitura.
- Iniciar/pausar atualiza o estado real. A agenda trata esses estados como consultas já confirmadas.
- Rascunho é individual por operador no documento da consulta, com salvamento automático. Navegar, trocar unidade, sair ou abrir prontuário/Pagamentos aguarda a gravação; falhas impedem a saída silenciosa.
- Prontuário e Pagamentos abrem as abas corretas conforme a especialidade.

## Odontologia

Marcadores clínicos, texto formal, alertas da anamnese quando existentes, recebimento de lançamentos existentes e retorno sugerido em 30 ou 21 dias, ou data personalizada. Agendamento preserva paciente/profissional e verifica todo o intervalo na grade da clínica.

## Psicologia

Marcadores de intervenção e síntese da sessão, rascunho explícito, progresso do contrato real, distinção pacote/avulsa e sugestão semanal/quinzenal. Pacote mensal mantém cálculo por presença e atestado: não se converte em carteira de créditos. A próxima sessão já gerada é reutilizada; avulsa abre o formulário existente para criar sessão e financeiro corretamente. Contratos e cobranças mensais são tratados nos fluxos existentes de Pagamentos.

## Verificação

`care_workflow_test.dart`, `clinical_care_view_test.dart` e matriz do emulador cobrem estados, escopo, duração, callbacks, telas de 320–1440px e autorização. Ver roteiro autenticado em `docs/design/care/TESTE.md`.

## Fidelidade visual às referências

O tema de Atendimento usa Plus Jakarta Sans incluída no app (licença OFL), superfícies tonais, marcadores sem contorno e botões verdes. Odontologia usa um painel contínuo com seções numeradas e rodapé de ações fixo; Psicologia conserva cartões independentes para registro, contrato/cobrança e próxima sessão. O contrato e os controles financeiros se organizam em duas colunas quando há espaço, empilhando no mobile. O menu mantém o logo original e usa destaque tonal no item ativo. Fluxos de gravação, presença, permissão e cobrança permanecem os mesmos.
