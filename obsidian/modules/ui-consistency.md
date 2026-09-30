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

Regra: cor só via `AppColors` (fundo, superfície, texto, borda); selos via `StatusChip` (pixel-idêntico na migração) e `chargeBadgeColor` (`isReplaced` = original parcelado, azul-cinza); moeda `formatBRL`, datas `formatDate*` (8 padrões), avisos `toast` — tudo com teste em `display_helpers_test.dart`.
Cabeçalhos padrão: AppBar global 44px (`AppBarTheme`: título 17 bold centralizado) + no corpo `PageTitle` (17 bold + subtítulo 12) e `MonthSelectorPill` (pílula radius 30 da tela de Relatórios; `labelAbove`/`labelBelow` p/ Competência/Saldo).
Densidade compacta (branch `teste-de-campos-novos`): tokens `AppTextStyles` reduzidos (h1 19, h2 16, subtitle/body 13, caption 11, chip 10); corpos 16→12, gaps 20/24→12/16. Exceções preservadas: agenda e pagamentos (AppBar 56 + fontes pinadas).

## Quando usar

Toda tela nova usa esses blocos; `grey[]`/`DateFormat`/`SnackBar` manual soltos são dívida.

## Gotchas

> [!tip]
> Quirk documentado: `formatDateAs` reproduz `à0` (o `s` de "às" vira segundos no intl) — idêntico ao original, de propósito.

Ver [[ui-theme]], [[flows/atendimento|atendimento]].
