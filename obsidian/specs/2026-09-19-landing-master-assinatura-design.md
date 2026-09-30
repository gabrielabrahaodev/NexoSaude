---
title: Spec landing + master + assinatura
tags:
  - nexosaude
  - spec
aliases:
  - spec-landing-master
name: spec-landing-master
description: Trial com porteira, master e assinatura.
---

# Landing + Master + Assinatura (trial e cobrança por usuário) — Design

Data: 2026-09-19. Status: aprovado em 4 seções. Branch: web-designer.

## 1. Landing (`/` — HTML estático, sem build)

Substitui o redirect `/ → dralaucielicosta.free.nf` (aposentado).
Hero com o produto + headline; modalidades (odonto/psico/multi); 3 passos;
CTA "Testar 7 dias grátis" (v1: fala com o dono, sem auto-cadastro) + "Entrar"
(`→ /sistema-interno/`). Visual: teal `#00C897` + tinta `#0f1113`, editorial à
esquerda, 1 tipografia com caráter, 1 movimento. Sem cards SaaS genéricos.

## 2. Master (dono da plataforma, dentro do app)

Seção "Master" visível só com `users.role == 'superadmin'` (1º via console).
Abas Owners (lista/detalhe, Bloquear/Liberar, Gerar mensalidade, Novo owner),
Débitos (`platform_debits` + selo aviso + baixa/dispensa), Trials (vence ≤3d,
expirados).

## 3. Assinatura do owner (mesmo login do sistema)

Item "Minha assinatura" (só owner): resumo `40 + 15×(n−1)` sobre staff das
clínicas dele (owner não conta); débitos com toggle Pix (`platform_config`)
+ "Avisei que paguei" por débito → selo no Master.

## 4. Modelo de dados e rules

- `users.role += 'superadmin'`; `clinics += {trialEndsAt, blockedByAdmin}`;
- `platform_debits/{id}` `{ownerId, users, amount, dueDate, status,
  paidAmount, avisoPagamento}`; `platform_config/geral` `{basePrice: 40,
  extraPrice: 15, pixKey}`.
- Trava login: `trial expirado OU blockedByAdmin` → tela de bloqueio total.
- Rules: superadmin lê/escreve users+clinics+debits; owner lê próprios débitos
  e atualiza só `avisoPagamento`; config: leitura autenticada, escrita superadmin.

## 5. Ordem de construção

1. Landing + remoção do redirect. 2. Dados+rules (roles, trial, config).
3. Trava no login. 4. Master (owners/débitos/trials + gerar mensalidade).
5. Assinatura do owner. 6. Bootstrap "Novo owner" + specs de aceite.

## 6. Critérios de aceite

- `/` abre a landing (sem redirect externo); `/sistema-interno/` intacto.
- Trial expirado ou bloqueio manual → clínica não entra (tela explicativa).
- Gerar mensalidade conta staff certo e cria débito +30d.
- Owner paga via Pix e avisa; Master dá baixa; valores conferem.

## Ver tamb�m

- [[screens/admin/master-screen|master-screen]] � abas Owners/D�bitos/Trials
- [[screens/admin/assinatura-page|assinatura-page]] � plano e trial com porteira
- [[screens/admin/landing-page|landing-page]] � porta de entrada
- [[foundation/01-prd|PRD]]
