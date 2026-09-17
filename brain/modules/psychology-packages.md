---
name: psychology-packages
description: Pacotes e sessões de psicologia — geração mensal, monthlyPeriod e billing rateado por presença.
---

# Pacotes / Sessões (Psicologia)

## O que é

Contrato recorrente (`psychology_schedules`: `package` vs `session`) que na criação
gera `treatment_plans` + N `appointments` + `financial` (pacote: 1/mês; avulso: 1/sessão).

## Quando usar

Criar/editar pacote, cobrança mensal, atestado, cálculo de valor do mês,
cancelamento de contrato (`_cancelSchedule` no form, modo edição).

## Arquivos-chave

- `lib/models/psychology_schedule_model.dart` — `generateSessionDates` (semanal até 31/12), `effectiveValue`
- Leitura de contratos: direto no Firestore (`psychology_schedules` por `clinicId` + `status active`); sem service dedicado
- `lib/services/package_billing.dart` — `PackageBilling.compute`: teto = pacote − desconto; divisor = previstas; cobrável = Realizado + falta sem atestado; parcial se incompleto (travado por `test/package_billing_test.dart`: 7 casos)
- `lib/models/financial_model.dart` — `monthlyPeriod: YYYY-MM`, `billingKind: package_monthly|session`, `installmentNumber: "Jan/2025 1/5"`

## Fluxos

- Pacote: sessões agrupadas por mês; cada conta vence dia 10 do mês seguinte, valor cheio do pacote (billing ajusta na UI por presença).
- Avulso: 1 conta por sessão, vence sessão + 7 dias.
- Editar contrato **não regenera** agenda/financeiro (só `add` gera). Cancelar na agenda não toca o financeiro.

## Regras / Gotchas

- `appointment` sem `scheduleId/planId` quebra o billing — geração deve sempre gravar.
- Por Sessão na cobrança exclui docs com `monthlyPeriod` (pacotes não aparecem na avulsa).
- Financeiro `paid/anticipated/cobrado` congela o valor; só `pending` recalcula.
