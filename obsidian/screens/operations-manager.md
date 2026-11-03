---
title: Operations Manager
tags:
  - nexosaude
  - brain
  - screens
name: screen-operations-manager
description: Shell de gestão com abas (estoque, fornecedores, procedimentos, taxas).
---

# OperationsManagerScreen

`lib/screens/operations/operations_manager_screen.dart`

## O que é

`TabBar` (com `SingleTickerProviderStateMixin`) hospedando as 4 tabs de gestão.

## Quando usar

Adicionar nova aba operacional.

## Gotchas

- Regras de cada aba vivem em `screens/operations-tabs.md`; aqui só navegação.
- Abas filtradas por sub-chave (`g_*`, 1 leitura do mapa); sem aba liberada, mensagem orienta falar com o proprietário.

## Ver também

- [[operations]] — cadastros de apoio
- [[operations-tabs]] — as 5 abas e seções

## Clinical Precision — 02/11/2026
Cabeçalho Gestão Operacional com clínica ativa, cinco abas horizontais por permissão e tema local claro/escuro. Sem telemetria/sincronização ilustrativa. Mantém TabController e ordem original, não cria rota paralela. Procedimentos usa ClinicalProceduresView, filtro local por categoria e busca, cartões, criação/edição existentes e confirmação de exclusão. Roteiro: docs/design/operations/TESTE.md. Outras abas mantêm as funções existentes com superfícies herdadas.
