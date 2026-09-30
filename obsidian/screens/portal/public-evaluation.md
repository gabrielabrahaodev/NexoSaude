---
title: Public Evaluation
tags:
  - nexosaude
  - brain
  - screens
name: screen-public-evaluation
description: Avaliação pública (link externo) que gera lead dentro da clínica.
type: screen
status: stable
updated: 2026-09-30
---

# PublicEvaluationScreen

`lib/screens/public/public_evaluation_screen.dart`

## O que é

Formulário público por `clinicId` (via link) que grava em `clinics/{id}/leads`.

## Quando usar

Captação, QR na recepção, pós-atendimento.

## Gotchas

- Rota fora do `AuthWrapper` — não exigir login aqui.
- Usa tipo privado na API pública (`library_private_types_in_public_api`) — tipar ao tocar.

## Ver também

- [[screens/operations/clinic-management|clinic-management]] — leads caem na clínica (`clinics/{id}/leads`)
- [[comms]] — WhatsApp e conteúdo
- [[screens/admin/landing-page|landing-page]] — outra porta de entrada pública
- Botão WhatsApp abre o chat **da clínica** (`whatsappNumber` canônico, fallback `phone/whatsapp`; sem número, avisa em vez de placeholder morto).
