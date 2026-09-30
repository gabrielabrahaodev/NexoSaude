---
title: Pix BR Code estático
type: integration
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - integracao
  - pix
  - portal
---

# Pix BR Code estático

Conteúdo movido de `modules/pix-brcode.md` em 2026-09-30 (ver lá o redirecionamento).

`lib/services/pix_brcode.dart` (+ port JS em `web/portal.html`)

## O que é

Gerador EMV/Bacen 100% local: chave + valor + txid + CRC16-CCITT-FALSE. Testado com vetor universal `29B1`. QR por débito no portal (qrcodejs) + copiar código. Custo zero, sem API, sem cadastro em PSP.

## Quando usar

Qualquer cobrança com `pixKey` da clínica; nome/cidade via espelho (`clinicName`). `pixKey` só owner escreve.

## Gotchas

> [!warning]
> Estático não confirma sozinho: continua valendo "Avisei que paguei" + baixa. Dinâmico com webhook exige PSP pago — fora de escopo.

Ver [[screens/portal/portal-page|portal-page]], [[modules/portal-mirror|portal-mirror]], [[foundation/01-prd|PRD]].
