---
title: Ortho News
tags:
  - nexosaude
  - brain
  - screens
name: screen-ortho-news
description: Feed de notícias de ortodontia com tradução e cache.
---

# OrthoNewsScreen

`lib/screens/news/ortho_news_screen.dart`

## O que é

Lista `OrthoArticle` via `NewsService.getLatestOrthoNews` (Europe PMC + Semantic Scholar por tema da clínica, traduzido, cache 60min).

## Quando usar

Conteúdo, educação do paciente, espera do consultório.

## Gotchas

- `_buildMinimalistCard` morto (unused) — remover ou usar.
- Construtor sem `key` nomeada; tipo privado na API pública.

## Ver também

- [[comms]] — cache, tradução e upload
