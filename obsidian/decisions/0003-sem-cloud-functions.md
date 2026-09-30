---
title: ADR 0003 — Sem Cloud Functions (plano Spark)
type: adr
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - adr
  - spark
---

# ADR 0003 — Sem Cloud Functions (plano Spark)

Fonte: `specs/2026-09-19-modo-atendimento-portal-design.md` §1/§2.

## Contexto

Projeto no plano Spark do Firebase (sem Cloud Functions): nada executa sozinho no servidor. Automação de WhatsApp agendado, remarcação automática e confirmação de Pix dinâmico exigiriam backend.

## Decisão

Tudo nasce de um clique no app ou de escrita pública com allowlist: Pix estático gerado localmente (ver [[integrations/pix-brcode]]), confirmação de envio humana, pedido de remarcação vira pendência (não executa sozinho), janela de slots mantida no login (`ensureWindow`).

## Consequências

- Custo zero de backend; cota Spark (50 mil leituras/dia) exige queries limitadas, cache e espelhos.
- "Avisei que paguei" + baixa manual; binários órfãos no Cloudinary com limpeza manual.
- Saída futura: Blaze com orçamento (citado no PRD como plano de saída).

## Alternativas

- Migrar para Blaze com Functions: descartado por enquanto (custo); registrado como saída se a cota estourar.
