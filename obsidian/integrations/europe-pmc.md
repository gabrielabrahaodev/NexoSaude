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
- Cache em memória — restart limpa; `formats` não usado (limpeza pendente, citado em [[modules/comms]]).

## TODOs

- TODO: chaves/limites das APIs (não constam no vault).
- TODO: decidir limpeza do campo `formats` morto.

Ver [[modules/comms]], [[screens/clinical/ortho-news|ortho-news]].
