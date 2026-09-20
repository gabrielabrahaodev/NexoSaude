---
title: Collections
tags:
  - nexosaude
  - brain
  - screens
name: screen-collections
description: Cobrança manual inteligente — pacotes mensais (psico) e avulsas com WhatsApp.
---

# CollectionsScreen

`lib/screens/financial/collections_screen.dart` + `widgets/` (`monthly_package_card`, `session_charge_card`, `charge_confirm_dialog`)

## O que é

Duas visões: `Pacotes Mensais` (`where monthlyPeriod`, só psico) e `Por Sessão`
(`dueDate` no mês, **exclui pacotes** via `_isPackageDoc`).

## Quando usar

Cobrar, confirmar envio do WhatsApp, baixa de pacote completo/parcial.

## Fluxos

- Pacote: card roxo com `PackageBill` ao vivo (`FutureBuilder` por `planId` + fallback paciente/mês, timeout 5s) → dialog Completo (baixa tudo) / Parcial (só registra contato). Enquanto calcula, `BillingSkeleton` (shimmer, sem pulo de layout); em erro, valor cheio + "Cálculo indisponível".
- Avulsa: card verde → WhatsApp → volta do app dispara `_showConfirmationDialog` → `cobrado`.
- Telefone: `_fetchPatientPhone` (phone → celular → whatsapp).

## Gotchas

- `Switch activeColor` já migrado para `activeThumbColor`; `TextEditingController` do parcial com `try/finally dispose`.
- `contactedToday` é só visual. Congelamento: `paid/anticipated/cobrado` não recalcula.

## Atualizações

- Selo "Avisei que paguei" por lançamento (do portal) com dispensar; baixa no fluxo normal. Ver [[portal-page]], [[remarcar-dialog]].
