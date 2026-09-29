---
name: screen-landing
description: Landing / (Tailwind, logo, preço, FAQ, form→WhatsApp).
title: Landing Page
tags:
  - nexosaude
  - brain
  - screens
  - plataforma
---

# Landing Page

`web/landing.html` → `/` (aposentou redirect externo); `web/logo.png` otimizado.

## O que é

Tailwind clara (brief do dono): hero com outcome, modalidades reais (sem Fisio — não existe o módulo), preço real (`R$ 40 + R$ 15`), FAQ, form que abre `wa.me` com lead pronto (sem backend). `SALES_WHATSAPP` precisa do número real.

## Quando usar

Porta de entrada + links "Minha assinatura" (rodapé). `deploy.bat` leva `logo` pra raiz e landing vira `index.html`.

## Gotchas

> [!warning]
> Claims do rascunho removidos (criptografia, confirmação automática, migração): só o que existe. Depoimentos/logos falsos: nunca.

Ver [[assinatura-page]], [[portal-page]], [[PRD]].

## Ver também

- [[master-screen]] — aprova os trials que a landing gera
- [[public-evaluation]] — outra porta pública
