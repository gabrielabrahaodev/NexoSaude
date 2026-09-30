---
title: ADR 0004 — Cache mensal deslizante da agenda
type: adr
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - adr
  - agenda
  - cota
---

# ADR 0004 — Cache mensal deslizante da agenda

<!-- fonte: lib/services/month_agenda_cache.dart:7,36-56,65,73,83-92 -->

## Contexto

A grade semanal lê appointments do Firestore e o plano Spark limita leituras. Recarregar o mês a cada navegação entre semanas estouraria a cota.

## Decisão

MonthAgendaCache mantém assinados os meses anterior, atual e próximo (janela deslizante via ensureWindow, idempotente e seguro no build). Sem TTL temporal: a invalidação é por cancelamento de assinatura fora da janela e limpeza total na troca de clínica. Leitura da semana visível via forWeek sobre os dados em memória. O frescor vem dos streams do Firestore, que empurram mudanças para o cache.

## Consequências

- Semana em cache custa zero leitura; mês novo lê somente ele; voltar é cache.
- Memória proporcional a 3 meses de agendamentos por clínica.
- Troca de clínica sempre limpa e recomeça, sem vazar dados entre tenants.

## Alternativas

- TTL temporal com expiração: não adotado, streams já invalidam por evento.
- Paginação por semana sem cache: descartado, multiplica leituras na navegação.

Ver [[modules/agenda]], [[screens/agenda/agenda-manager]].
