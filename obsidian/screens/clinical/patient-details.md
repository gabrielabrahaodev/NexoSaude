---
title: Patient Details
tags:
  - nexosaude
  - brain
  - screens
name: screen-patient-details
description: Ficha do paciente com tabs dinâmicas por tipo de clínica.
type: screen
status: stable
updated: 2026-09-30
---

# PatientDetailsScreen

`lib/screens/patients/patient_details_screen.dart`

## O que é

Cabeçalho (`_HeaderSummaryRow` + `PatientSmartContextCard`) + `TabBar` cujo tamanho vem de `ClinicCapabilities.patientTabCount` (dental 9, psico 7). Header tem 4 cards: assiduidade, A Receber, Recebido e Custo Operacional (soma `expenses` por `relatedPatientId`) — os totais moram aqui, não na aba Pagamentos.

## Quando usar

Adicionar/remover aba, mudar visibilidade por tipo.

## Fluxos

- Abas condicionais: `canShowBudgets/Odontogram/Lab`; `_buildVisualTab` cai em placeholder fora da dental.

## Gotchas

- `TabBar` e `TabBarView` precisam ter os mesmos `if`s na mesma ordem — divergência quebra o índice.

## Atualizações

- Aba Cadastro: seção Portal em máquina de estados — sem aceite não há link nem cópia; gerar exige diálogo LGPD (grava `accepted/at/via/by`); revogar mata espelho + limpa token + `accepted:false`/`revokedAt`. Data do aceite exibida no cartão. Excluir paciente apaga o espelho na cascata. Ver [[screens/portal/portal-page|portal-page]], [[portal-mirror]].
