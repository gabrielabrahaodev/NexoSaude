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

- Lista exata em 2026-09-30: 53 índices em firestore.indexes.json, todos COLLECTION, grupos appointments, financial, treatment_plans, expenses, lab_orders, patients, budgets, users, inventory, docs, clinical_records, clinics, suppliers, procedures. Exceção: users.allowedClinics usa CONTAINS. Sem fieldOverrides.
<!-- fonte: firestore.indexes.json -->
- Deploy: firebase.json declara `firestore.rules` e `firestore.indexes.json` para o CLI; hosting sai por `firebase deploy --only hosting --project=nexosaude` via deploy.bat; rules saem por migrate/rules-release.js via REST; índices seguem o mesmo CLI (`firebase deploy --only firestore:indexes`, derivado do padrão do repo).
<!-- fonte: firebase.json: firestore; deploy.bat; migrate/rules-release.js -->

Ver [[data-model/collections]].
