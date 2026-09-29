---
name: module-ui-consistency
description: AppColors, StatusChip e helpers de display com teste.
title: Consistência Visual e Helpers
tags:
  - nexosaude
  - brain
  - modules
  - ui
---

# Consistência Visual e Helpers

`lib/ui/app_theme.dart`, `lib/widgets/status_chip.dart`, `lib/widgets/page_header.dart`, `lib/utils/display.dart`

## O que é

Regra: cor só via `AppColors` (fundo, superfície, texto, borda); selos via `StatusChip` (pixel-idêntico na migração); moeda `formatBRL`, datas `formatDate*` (8 padrões), avisos `toast` — tudo com teste em `display_helpers_test.dart`.
Cabeçalhos padrão: AppBar (`surface`, elevation 0, título bold centralizado) + no corpo `PageTitle` (20 bold + subtítulo cinza) e `MonthSelectorPill` (pílula radius 30 da tela de Relatórios; `labelAbove`/`labelBelow` p/ Competência/Saldo).

## Quando usar

Toda tela nova usa esses blocos; `grey[]`/`DateFormat`/`SnackBar` manual soltos são dívida.

## Gotchas

> [!tip]
> Quirk documentado: `formatDateAs` reproduz `à0` (o `s` de "às" vira segundos no intl) — idêntico ao original, de propósito.

Ver [[ui-theme]], [[atendimento]].
