---
name: module-pix-brcode
description: BR Code Pix estático local (grátis, sem PSP) + QR no portal.
title: Pix BR Code Grátis
tags:
  - nexosaude
  - brain
  - modules
  - portal
---

# Pix BR Code Grátis

`lib/services/pix_brcode.dart` (+ port JS em `web/portal.html`)

## O que é

Gerador EMV/Bacen 100% local: chave + valor + txid + CRC16-CCITT-FALSE. Testado com vetor universal `29B1`. QR por débito no portal (qrcodejs) + copiar código. Custo zero, sem API, sem cadastro em PSP.

## Quando usar

Qualquer cobrança com `pixKey` da clínica; nome/cidade via espelho (`clinicName`).

## Gotchas

> [!warning]
> Estático não confirma sozinho: continua valendo "Avisei que paguei" + baixa. Dinâmico com webhook exige PSP pago — fora de escopo.

Ver [[portal-page]], [[portal-mirror]], [[foundation/01-prd|PRD]].
