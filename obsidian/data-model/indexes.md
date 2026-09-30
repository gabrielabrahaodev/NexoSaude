---
title: Índices Firestore
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - data-model
  - firestore
---

# Índices Firestore

Extraído de [[modules/financial]] e [[screens/reports/kpi-dashboard|kpi-dashboard]] (mencionam `firestore.indexes.json` e índices compostos).

## Índices conhecidos (citados no vault)

- `financial(clinicId, status)` — pendentes do KPI e próximos vencimentos ([[screens/reports/kpi-dashboard|kpi-dashboard]]).
- `appointments(clinicId, date)` — agendamentos de hoje ([[screens/reports/kpi-dashboard|kpi-dashboard]]).
- Queries com `whereIn` + ordenação exigem índice composto (ver `firestore.indexes.json`) — [[modules/reports-oracle]].
- DRE/Livro Caixa: união de queries mensais por campo de data (exato, dedupe por id); índices em `firestore.indexes.json` — [[modules/reports-oracle]].

## Regras

- `FinancialModel.isPaid`: `paid`/`anticipated` ou `paidAmount >= amount`.
- Status de filtro: `whereIn: ['pendente', 'pending']` (legado tem os dois) — [[modules/financial]].
- Índices compostos em `firestore.indexes.json` são obrigatórios para as queries (fazer deploy após mudar filtro) — [[modules/financial]].

## TODOs

- TODO: importar a lista exata de `firestore.indexes.json` do código.
- TODO: registrar comando de deploy dos índices (`firebase deploy --only firestore:indexes`).

Ver [[data-model/collections]].
