---
title: Patient Details
tags:
  - nexosaude
  - brain
  - screens
name: screen-patient-details
description: Ficha do paciente com tabs dinâmicas por tipo de clínica.
---

# PatientDetailsScreen

`lib/screens/patients/patient_details_screen.dart`

## O que é

`TabBar` cujo tamanho vem de `ClinicCapabilities.patientTabCount` (dental 9, psicologia 6).

## Quando usar

Adicionar/remover aba, mudar visibilidade por tipo.

## Fluxos

- Abas condicionais: `canShowBudgets/Odontogram/Lab`; `_buildVisualTab` cai em placeholder fora da dental.

## Gotchas

- `TabBar` e `TabBarView` precisam ter os mesmos `if`s na mesma ordem — divergência quebra o índice.

## Atualizações

- Aba Cadastro: seção Portal em máquina de estados — sem aceite não há link nem cópia; gerar exige diálogo LGPD (grava `accepted/at/via/by`); revogar mata espelho + limpa token + `accepted:false`/`revokedAt`. Data do aceite exibida no cartão. Excluir paciente apaga o espelho na cascata. Ver [[portal-page]], [[portal-mirror]].

## Variante Clinical Dark — PR #2

`clinical_patient_screen.dart` compõe a ficha com menu global/unidade, identificação real, CPF mascarado, selo LGPD somente com `lgpdPortalConsent.accepted == true`, abas por `ClinicCapabilities`, indicadores, contexto e conteúdo em uma rolagem vertical. Abertura pela lista inicia no Odontograma em clínicas dentais; deep-links continuam respeitando `initialTab` (inclusive Cadastro, Prontuário e Pagamentos), e psicologia inicia em Cadastro com seis abas.

No Odontograma, a página também exibe tratamentos e cobranças abaixo do mapa. As abas Tratamentos/Pagamentos mantêm acesso direto ao mesmo conteúdo. Novo tratamento conduz ao fluxo existente de Orçamentos. Receber pagamento leva às cobranças reais para escolher o lançamento; nenhum valor do HTML é usado. A tabela preserva famílias de parcelamento e opções de estorno/cancelamento, sem oferecer recibo inexistente. Custos e repasses continuam acessíveis após as cobranças.

A rota reutiliza o shell do dashboard com conteúdo de detalhe; troca de menu ou unidade encerra a exibição da ficha antiga. Leitura inicial de paciente e todos os indicadores usam escopo da clínica. Consultas/streams dos indicadores são preparados uma vez na montagem. Os valores da referência e percentuais de assiduidade não são inseridos como dados reais.

Componentes puros em `clinical_patient_view.dart` permitem verificar identidade, ações financeiras, tratamento e odontograma sem Firebase. A flag `AGENDA_CLINICAL_DARK=false` mantém a ficha anterior para comparação.
