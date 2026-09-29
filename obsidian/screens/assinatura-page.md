---
name: screen-assinatura-page
description: Minha assinatura fora do app (login owner, débitos, Pix, aviso).
title: Página Assinatura do Owner
tags:
  - nexosaude
  - brain
  - screens
  - plataforma
---

# Página Assinatura do Owner

`web/assinatura.html` → `/assinatura.html` (link no rodapé da landing)

## O que é

Mesmo login do sistema: resumo do plano (`40+15×(n−1)` sobre staff único), débitos com toggle Pix + "Avisei que paguei" por débito. Saiu do Flutter (índice 14 removido, menu em 14 chaves).

## Quando usar

Owner acompanha e paga a plataforma sem entrar no operacional.

## Gotchas

> [!tip]
> Rules já cobriam: owner lê próprios débitos e atualiza só `avisoPagamento`. Zero mudança de rule.

Ver [[master-screen]], [[portal-page]], [[PRD]].
