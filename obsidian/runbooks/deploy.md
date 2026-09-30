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

- Passo a passo (deploy.bat na raiz): 0 carimba versão via tool/bump_version.ps1 (gera web/version.json); 1 flutter clean + flutter build web com base-href /sistema-interno/; 2 reorganiza build/web (app vai para sistema-interno, páginas públicas e landing voltam para a raiz como index.html); 3 firebase deploy --only hosting --project=nexosaude.
<!-- fonte: deploy.bat; tool/bump_version.ps1 -->
- Hosting: `firebase deploy --only hosting --project=nexosaude` (deploy.bat). Rules: migrate/rules-release.js publica via REST com service account (contorna 403 do test no CLI). Índices: mesmo CLI (`firebase deploy --only firestore:indexes`), derivado do padrão do repo + firebase.json que declara rules e indexes.
<!-- fonte: deploy.bat; migrate/rules-release.js:1-30; firebase.json -->

Ver [[data-model/indexes]], [[modules/portal-mirror]].
