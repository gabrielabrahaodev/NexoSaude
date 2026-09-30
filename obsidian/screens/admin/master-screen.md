---
name: screen-master
description: Master da plataforma (owners, débitos, trials) só superadmin.
title: Master da Plataforma
tags:
  - nexosaude
  - brain
  - screens
  - plataforma
---

# Master da Plataforma

`lib/screens/master/master_screen.dart`

## O que é

3 abas do dono da plataforma: Owners (bloquear/liberar, gerar mensalidade `40+15×(n−1)`, novo owner + clínica + trial 7d via app Auth temporário), Débitos (baixa/dispensa de aviso) e Trials (vence ≤3d, expirados).

## Quando usar

Gestão comercial: provisionar, cobrar, suspender. Primeiro `superadmin` via console.

## Gotchas

> [!warning]
> Trial expirado OU `blockedByAdmin` barra o login (`role_check_screen`) — superadmin passa direto.

Ver [[screens/admin/assinatura-page|assinatura-page]], [[portal-mirror]], [[foundation/01-prd|PRD]].
