---
title: Integração WhatsApp
type: integration
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - integracao
  - whatsapp
---

# Integração WhatsApp

Fonte: [[modules/comms]] + `Requisitos.md` RN-59/60/61.

## O que existe no vault

- `lib/services/whatsapp_helper.dart` — `getMessage` (3 templates rotativos anti-spam), `openWhatsApp`; normalização de telefone (só dígitos, ≥10, prefixa `55`).
- `lib/utils/external_link.dart` — `openBlankTab` + `openWhatsAppSafe`/`openLinkSafe`: aba em branco no gesto para o bloqueador de pop-up não matar.
- Confirmação humana: ao voltar do WhatsApp (`AppLifecycleState.resumed` + `_currentProcessingId`), pergunta "Você enviou?" — SIM marca como cobrado (`cobrado` + `lastContactDate` + `contactHistory`).
- Cobrança grava `clinical_records` ("Cobrança via WhatsApp", texto exato + operador + data).
- `openWhatsApp` pode falhar (sem app) — sempre tratar `success == false` com SnackBar.

## Limites (plano Spark)

- Sem automação agendada (impossível sem backend); envio segue manual via `wa.me`.

## TODOs

- TODO: número oficial da clínica / conta comercial (não consta no vault).

Ver [[modules/comms]], [[screens/financial/collections|collections]].
