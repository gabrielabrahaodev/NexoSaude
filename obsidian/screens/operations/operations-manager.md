---
title: Operations Manager
tags:
  - nexosaude
  - brain
  - screens
name: screen-operations-manager
description: Shell de gestão com abas (estoque, fornecedores, procedimentos, taxas).
type: screen
status: stable
updated: 2026-09-30
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
- [[screens/operations/operations-tabs|operations-tabs]] — as 5 abas e seções
