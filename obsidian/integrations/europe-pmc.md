---
title: Integração Europe PMC
type: integration
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - integracao
  - noticias
---

# Integração Europe PMC (+ Semantic Scholar)

Fonte: [[modules/comms]] + [[screens/clinical/ortho-news|ortho-news]].

## O que existe no vault

- `lib/services/news_service.dart` — `getLatestOrthoNews(clinicType)` (Europe PMC + Semantic Scholar por tema da clínica, traduzido, cache 60min).
- `lib/screens/news/ortho_news_screen.dart` — lista `OrthoArticle`; conteúdo/educação do paciente (espera do consultório).
- Cache em memória — restart limpa; `formats` não usado (verificado inexistente no código, citado em [[modules/comms]]).

## TODOs

- Chaves: nenhuma no código. Europe PMC (ebi.ac.uk REST) e Semantic Scholar (graph API) são chamadas públicas sem apiKey; cache 60min com teto de 30.
<!-- fonte: lib/services/news_service.dart:11-17,42-49,91-97,115-144 -->
- TODO: (owner) confirmar limites de requisições das APIs públicas (não documentados no repo).
- Campo formats inexistente no código do projeto em 2026-09-30 (grep em lib, web e migrate retorna ocorrências só em plugin de terceiros). Nada a limpar no app.
<!-- fonte: grep formats em lib, web, migrate -->

Ver [[modules/comms]], [[screens/clinical/ortho-news|ortho-news]].
