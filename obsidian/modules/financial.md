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

- [[collections]] — cobrança e baixa no dia a dia
- [[financial-report]] — extrato, taxas e PDF
- [[expenses]] — o outro lado do caixa
- [[kpi-dashboard]] — a receber/inadimplência
- [[patient-details]] — aba Pagamentos por paciente
- [[assinatura-page]] — débitos do owner (plataforma)


## Laboratório independente — PR #2

Pedidos são criados somente nos kanbans geral e individual, nunca no recebimento. Se houver custo, `LabService.createOrder` cria uma despesa pendente em uma transação com o pedido, para Relatórios → A Pagar; sem custo, não cria despesa. Estorno/cancelamento de recebimentos preserva pedidos e custos de laboratório. Ver [[clinic-lab]] para vínculos, idempotência, campos novos e tratamento dos dados legados.


## Cobranças multi-clínica — PR #2

A apresentação clínica usa fila unificada e inspetor; ver [[collections]] para escopo explícito por unidade, rateio e apuração. Confirmar contato nunca é baixa. Pacotes ainda pendentes podem fixar a apuração revisada, preservando o valor original; confirmação é atômica e idempotente. Recebimento usa PatientFinancialTab e famílias existentes. Lote e reagendamento são manuais, sem SMS nem confirmação bancária. O fallback anterior permanece na flag de comparação.

## Parcial, cobrança e projeção — conferência 03/11/2026

O cálculo deve distinguir **valor original**, **recebido** e **restante**. `FinancialService.partialRemainder` calcula `amount - paidAmount - payValue`; `partialSummary` e `restoredAmount` tratam formatos legados e parcelas-filhas de maneira específica. No portal, `buildPortalMirror` soma `amount - paidAmount` dos débitos elegíveis em aberto. Exemplo legado: `amount = 200` e `paidAmount = 80` implica **R$ 120,00** em aberto, sem cobrar os R$ 80,00 novamente.

No formato novo, `amount` pode guardar o saldo restante e filhas registram pagamentos: **não** somar filhas ao saldo nem contar baixa duas vezes. Confirmar valor exibido, mensagem WhatsApp, Pix efetivamente gerado, Livro Caixa, oráculo, filtros, estorno e cobrança de pacote antes de liberar. Contato no WhatsApp e `avisoPagamento` público são avisos, **não comprovação de liquidação**.

Na variante clínica, `CollectionQueueService` usa consultas explícitas por `clinicId` e um inspetor de cobranças; regras de apresentação não substituem a autorização das Firestore Rules. Pedidos de laboratório com custo geram despesas pelo serviço de laboratório, não pelo recebimento de pacientes. Consulte [[auditoria-codigo-2026-11-03]] e [[remodelagem-plano-testes]].

- Aprovação de orçamento: agora transacional e idempotente por budgetId, com conferência do snapshot atual e geração das Tags clínicas por linha junto de plano/receitas/despesas. Concluir Tag não recebe nem quita valores. Modelo/migração: docs/design/agenda/TAGS.md.
