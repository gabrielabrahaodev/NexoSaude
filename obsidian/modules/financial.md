---
title: Financial
tags:
  - nexosaude
  - brain
  - modules
name: financial-module
description: Contas a receber/pagar, cobrança via WhatsApp, despesas e processamento de pagamentos.
---

# Financeiro

## O que é

`financial` (receitas), `expenses` (despesas), cobrança manual com WhatsApp e baixa de pagamentos.

## Quando usar

Cobrança, pacotes mensais, relatório financeiro, despesa recorrente, recebimento/estorno.

## Arquivos-chave

- `lib/services/financial_service.dart` — `getByPatientId`, `processPayment` (+`computeInstallments` puro, `parentId` nas filhas), `voidPayment`, `cancelCharge` (soft `cancelado`, +família), `recordingFor`, `recreateCharge`/`recreatedData`, `editPendingCharge`
- `lib/services/payment_service.dart` — SÓ `reverseTransaction` (livro-caixa); `receivePayment` removido (morto)
- `lib/services/expense_service.dart` — `addExpense`, `addRecurringExpense`, `markAsPaid`, `getByMonth`
- `lib/services/whatsapp_helper.dart` — mensagens rotativas + abertura do WhatsApp
- `lib/models/financial_model.dart` (`_toDouble` defensivo, `monthlyPeriod`, `billingKind`), `lib/models/expense_model.dart`
- `lib/services/package_billing.dart` — rateio do pacote por presença (puro, sem Firebase)

## Fluxos

- Cobrança: abre WhatsApp → ao voltar, dialog confirma envio → marca `cobrado` + `lastContactDate` + `contactHistory`.
- Pacote mensal: valor ao vivo por `PackageBill` (`FutureBuilder` + `BillingSkeleton`, timeout 5s) → dialog `Pagar Completo` (baixa tudo) vs `Parcial` (só registra contato); congela no `paid`.
- Por Sessão exclui pacotes (`billingKind`/`monthlyPeriod`).
- Status de filtro: `whereIn: ['pendente', 'pending']` (legado tem os dois).

## Regras / Gotchas

- `FinancialModel.isPaid`: `paid`/`anticipated` ou `paidAmount >= amount`.
- Índices compostos em `firestore.indexes.json` são obrigatórios para as queries (fazer deploy após mudar filtro).
- `contactedToday` (`lastContactDate` == hoje) só muda a cor do card.

## Ver também

- [[screens/financial/collections|collections]] — cobrança e baixa no dia a dia
- [[screens/financial/financial-report|financial-report]] — extrato, taxas e PDF
- [[screens/financial/expenses|expenses]] — o outro lado do caixa
- [[screens/reports/kpi-dashboard|kpi-dashboard]] — a receber/inadimplência
- [[screens/clinical/patient-details|patient-details]] — aba Pagamentos por paciente
- [[screens/admin/assinatura-page|assinatura-page]] — débitos do owner (plataforma)
