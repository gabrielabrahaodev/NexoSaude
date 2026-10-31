---
title: Patient Tabs
tags:
  - nexosaude
  - brain
  - screens
name: screen-patient-tabs
description: Abas da ficha do paciente — cadastro, anamnese, orçamentos, tratamentos, prontuário, odonto, lab, docs, financeiro.
---

# Patient Tabs

`lib/screens/patients/tabs/` (9 arquivos)

## O que é

- **patient_details_tab**: edição do cadastro (`patients/{id}`).
- **anamnesis_tab**: doc único `anamnesis/{patientId}` (+ espelho em `patients`); switches de hábitos.
- **budgets_tab**: `budgets` do paciente (`_treatmentService` morto — remover).
- **treatments_tab**: agrupa por `planId`; parâmetro `sum` sombreia tipo — renomear para `total`.
- **clinical_record_screen** (`ClinicalRecordTab`): lista `clinical_records` com selo por tipo — "Cobrança" (verde, envios de WhatsApp) vs "Atendimento" (azul).
- Pagamentos: filhas com pai presente ficam só no modal da família (`familyOf`/`visibleCharges`/`familyProgress`, testados); pai "Parcelado" abre o modal com progresso, selo "A receber da operadora" no cartão e estorno/cancelamento preservados.
- **odontogram_screen**: `patients/{id}/clinical_data/odontogram` (`teeth` + `lastUpdate`); `scale` depreciado.
- **patient_lab_tab**: `lab_orders` do paciente; catch vazio.
- **patient_docs_tab**: `DocumentService.getDocs` por categoria; `if` sem chaves.
- **patient_financial_tab**: extrato + taxas do perfil + gera `financial`/`expenses`/`lab_orders`; filtros de valor mín/máx, procedimento (título/categoria) e ordenação (registro, vencimento ↑↓; nulos por último); totais sempre na lista cheia; tem `dead_code` e casts desnecessários — limpar ao tocar.

## Quando usar

Qualquer evolução da ficha do paciente.

## Gotchas

- Quase todas usam `value:` de dropdown depreciado → `initialValue`.

## Ver também

- [[patient-details]] — shell da ficha com as tabs
- [[clinical]] — conteúdo clínico das abas

## Apresentação Clinical Dark

Odontograma usa coroas geométricas escuras de cinco faces e mantém os mesmos IDs FDI e status persistidos. Toque em face abre as ações existentes; pressão prolongada abre as ações da raiz (endo/implante). Zoom, ajuste à tela e salvar são funcionais. Falha de leitura não vira um odontograma saudável editável: mostra erro e permite tentar novamente.

Tratamentos e Pagamentos aceitam `embedded` para compor a rolagem exclusivamente de suas próprias abas; nunca são incluídos em Odontograma. Seu modo independente continua disponível. Os botões usam os serviços/diálogos anteriores. As cores adaptativas das demais abas acompanham a variante sem alterar a preferência global de tema.


Aba Laboratório: o mesmo kanban visual do menu geral, restrito ao paciente. Novo Pedido usa o formulário compartilhado e gera conta a pagar apenas com custo explícito. A aba Pagamentos não cria laboratório. Ver [[clinic-lab]].
