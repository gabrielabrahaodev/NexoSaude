---
title: Patient List
tags:
  - nexosaude
  - brain
  - screens
name: screen-patient-list
description: Lista clínica de pacientes com busca, filtros reais, CSV e ficha integrada.
---

# PatientListScreen

`lib/screens/patients/patient_list_screen.dart`

## O que é

Lista clínica conforme a referência screen(4).png / code(3).html. `ClinicalPatientListView` separa apresentação de `PatientListService` e `PatientListEntry`. Stream `patients` filtrado pela clínica; busca local por nome sem acentos, CPF, telefone e prontuário cadastrado. Ordenação alfabética, cadastro recente ou atendimento finalizado recente.

## Quando usar

Buscar paciente, abrir detalhes, excluir (tap no menu ou long-press).

## Fluxos

- Excluir → confirmação → `_confirmDelete` (`deletePatientCascade`) → SnackBar.
- `_patientService` é campo `final` (não instanciar no build).

## Gotchas

- No layout clínico não há Hero nem nova rota ao abrir uma ficha. A apresentação antiga continua sob a flag de comparação.
- Consultas complementares são compartilhadas por unidade, não por cartão: pendências em financial, planos ativos, orçamentos pendentes e agendamentos em janela de 90 dias. Duplicatas financeiras são removidas por ID; cancelados/substituídos/pagos não entram nas pendências.
- O último atendimento exibido é um agendamento Finalizado nos últimos 90 dias. Não representa todo o histórico do prontuário.
- Falha nas fontes complementares mostra erro, bloqueia os filtros dependentes e não apresenta zeros como dados válidos. Busca e LGPD continuam disponíveis.
- Prontuário só aparece se recordNumber/prontuario/medicalRecordNumber estiver registrado. Não gerar numeração a partir do ID. Consentimento usa lgpdPortalConsent.accepted.
- Exportar CSV usa o conjunto filtrado/ordenado, CPF integral e proteção contra fórmulas; não exporta token do portal. Na tela o CPF é mascarado. Sem contexto complementar, essas colunas ficam vazias.
- Ctrl/⌘+K foca a busca. O workspace exclui o foco da lista enquanto a ficha está aberta, preservando seu estado ao voltar.

## Ver também

- [[patient-details]] — ficha que abre daqui
- [[create-patient]] — cadastro via FAB
- [[patients]] — risco, cascata e busca
- [[kpi-dashboard]] — "Ver em Pacientes"


## Abertura no dashboard — PR #2

No layout clínico, o shell fornece `onOpenPatient` por `PatientWorkspace`: clicar no paciente troca somente o conteúdo da direita. Não cria rota nem dashboard adicional. A lista fica montada, preservando busca e estado ao voltar. Troca de clínica remonta o workspace pela chave e remove o paciente anterior. O uso isolado da lista e a flag legada mantêm a rota anterior como fallback.


## Referência da lista — PR #2

Cabeçalho com contagem real, exportação e Novo Paciente; painel de busca/filtros/ordenação; cartões com avatar quadrado, prontuário/status e ações. O primeiro cartão (ou último aberto) recebe destaque 360°. Novo Paciente usa o formulário existente. Claro/escuro e larguras de 320 a 1280px cobertos por testes. Não adicionar números ilustrativos, assiduidade, estágio de anamnese ou laboratório sem fonte. Roteiro em `docs/design/patients/LISTA.md`.
