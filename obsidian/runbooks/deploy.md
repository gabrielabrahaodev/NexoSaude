---
title: Deploy
type: runbook
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - runbook
  - deploy
---

# Deploy

Fragmentos que existem no vault (fonte: [[modules/portal-mirror]], `Requisitos.md` RN-72). Sem runbook completo hoje.

## O que existe no vault

- Deploy completo: `powershell -File tool/bump_version.ps1` → `flutter build web` → sync `sistema-interno` → `firebase deploy --only hosting`. O app avisa "Nova versão" sozinho (`version.json` + localStorage).
- `flutter build web` NÃO atualiza `build/web/sistema-interno/` (cópia manual) — sincronizar `web/*.html` → lá antes de `firebase deploy --only hosting`.
- `deploy.bat` leva `logo/portal/assinatura` + landing vira `index.html` (RN-72).
- Índices: fazer deploy após mudar filtro (`firestore.indexes.json`) — ver [[data-model/indexes]].

## TODOs

- TODO: escrever o passo a passo completo (pré-requisitos, rollback, verificação pós-deploy).
- TODO: confirmar comando de deploy das rules/índices (`firebase deploy --only firestore:rules,indexes`).

Ver [[data-model/indexes]], [[modules/portal-mirror]].
