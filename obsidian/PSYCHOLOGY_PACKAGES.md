---
title: Pacotes Psicologia (billing)
tags:
  - nexosaude
  - psicologia
  - billing
aliases:
  - psychology-packages-doc
name: psychology-packages-doc
description: Billing mensal por presença (implementado).
---

# Psychology Package Payment - Monthly Billing (IMPLEMENTED Sep 2026)

## Context
For psychology clinics, packages support **monthly billing** — all sessions in the same calendar month grouped into one financial record, with **attendance-based adjustment**.

---

## Current Behavior
| Type | Financial Records Generated |
|------|----------------------------|
| **Package** | 1 record **per month** (`monthlyPeriod: YYYY-MM`, `billingKind: package_monthly`), fixed package value, dueDate = day 10 of next month, `installmentNumber: "Jan/2025 1/5"` |
| **Avulso** | **1 session only** on the selected date (no recurrence); 1 record, dueDate = session + 7 days, `installmentNumber: 1/1` |

---

## Implemented Behavior (Monthly Billing for Packages)
```
Package: R$ 500/month, 5 sessions in Jan/2025, due 10/02, installmentNumber="Jan/2025 1/5"

Billing adjustment (PackageBilling.compute):
- 5 sessions, all attended (or missed WITHOUT certificate) → R$ 500
- 5 sessions, 1 missed WITH certificate → R$ 400 (4/5 × 500)
- Incomplete month (3/5 finalized, all attended) → partial R$ 300
```
Rules (locked decisions): partial month charges partial · divisor = previstas · missed WITH certificate deducts (and skips risk) · third-party discount applied BEFORE split · `paid` freezes the value.

---

## Design Decisions (LOCKED Sep 2026)

### 1. Due Date Strategy
**Decided: C — fixed day 10 of next month** (`DateTime(year, month + 1, 10)`).

### 2. Partial Month
**Decided: partial** — charge only finalized sessions (`billable/previstas × package`).

### 3. New Fields
`monthlyPeriod: "YYYY-MM"` + `billingKind: package_monthly|session` in FinancialModel;
`scheduleId`/`planId`/`monthlyPeriod`/`attendanceStatus`/`hasMedicalCertificate` in appointments.

### 4. Installment Number Format
`"MMM/yyyy N/T"` (ex: `"Jan/2025 1/5"`) — compatible with `treatments_tab.dart` grouping.

---

## Implementation (DONE Sep 2026)

1. **`psychology_schedule_form_screen.dart`** — monthly grouping + `billingKind`/`scheduleId`; avulso = single session
2. **`financial_model.dart`** — `monthlyPeriod?`, `_toDouble` defensive parsing
3. **`appointment_model.dart`** — `scheduleId/planId/monthlyPeriod/attendanceStatus/hasMedicalCertificate`
4. **`services/package_billing.dart`** (new, pure) + `BillingSkeleton` + card billing ao vivo na cobrança
5. **Finalize dialog** — psychology without procedure dropdown; "Apresentou Atestado" checkbox; risk exempts certificate
6. **`treatments_tab.dart`** — no changes needed · **`patient_financial_tab.dart`** — filters/sort only

---

## Pseudocode for Monthly Grouping (esboço inicial — SUPERSEDED)

> Histórico: rascunho da proposta original (valor = sessões × valor unitário,
> vencimento no último dia do mês). **A implementação final difere**:
> valor cheio do pacote por mês (`effectiveValue` = pacote − desconto) e
> vencimento fixo **dia 10 do mês seguinte** — ver "Current Behavior" acima e
> `psychology_schedule_form_screen.dart:_generateAppointments`.

```dart
// Group sessions by month
final Map<String, List<DateTime>> sessionsByMonth = {};
for (final date in sessionDates) {
  final key = "${date.year}-${date.month.toString().padLeft(2, '0')}"; // "2025-01"
  sessionsByMonth.putIfAbsent(key, () => []).add(date);
}

// Create financial record per month
int monthIndex = 0;
for (final entry in sessionsByMonth.entries) {
  final monthKey = entry.key; // "2025-01"
  final monthSessions = entry.value;
  monthIndex++;
  
  final totalSessions = monthSessions.length;
  final amount = totalSessions * schedule.sessionValue;
  
  // Due date = last day of month
  final year = int.parse(monthKey.split('-')[0]);
  final month = int.parse(monthKey.split('-')[1]);
  final dueDate = DateTime(year, month + 1, 0); // last day
  
  // Installment format: "Jan/2025 1/5"
  final monthName = DateFormat('MMM/yyyy', 'pt_BR').format(DateTime(year, month));
  final installmentNumber = "$monthName $monthIndex/${sessionsByMonth.length}";
  
  batch.set(finRef, {
    // ... existing fields
    'amount': amount,
    'dueDate': Timestamp.fromDate(dueDate),
    'installmentNumber': installmentNumber,
    'monthlyPeriod': monthKey, // NEW FIELD
    'planId': planRef.id,
  });
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Package spans year boundary (Dec → Jan) | Works naturally with YYYY-MM key |
| Only 1 month of sessions | Single record, installmentNumber="Jan/2025 1/1" |
| Month with 5 weeks (5 sessions) | Higher amount for that month |
| Patient cancels mid-package | `_cancelSchedule`: schedule → `cancelled`, futuras não finalizadas → `Cancelado`, financeiros `pendente/pending` do plano → `Cancelado` (finalizados/pagos intactos) |
| Package edited (add/remove sessions) | **Não regenera** — edição atualiza só o schedule; só o `add` gera agenda/financeiro |

---

## Compatibility Check

| Component | Impact |
|-----------|--------|
| **CollectionsScreen** | Works — filters by `status: pending` + `dueDate` range |
| **PatientFinancialTab** | Works — lists all financial records |
| **TreatmentsTab** | Works — groups by `planId`, shows `installmentNumber` |
| **Reports** | Enhanced — can filter by `monthlyPeriod` |
| **WhatsApp Cobrança** | Works — each monthly record has dueDate |

---

## Testing Scenarios

1. **Pacote 12 sessões, 1x/semana, inicia 15/01** → 3 meses de parcelas
2. **Pacote 24 sessões, 2x/semana, inicia 01/03** → 6 meses
3. **Pacote curto (4 sessões no mesmo mês)** → 1 parcela
4. **Editar pacote ativo** → NÃO regenera financeiro (só atualiza o schedule)
5. **Cancelar contrato** → futuras → `Cancelado`, financeiros pendentes do plano → `Cancelado`
6. **Cancelar paciente** → Cascade delete financial records

---

## Open Questions (ANSWERED Sep 2026)

1. **Due date:** Fixed day 10 (C) ✅
2. **Partial month:** partial ✅
3. **`monthlyPeriod` field:** Yes ✅ (+ `billingKind`)
4. **Backfill:** Not needed — old docs without new fields default safely (no certificate, full charge)

---

## Related Files Reference

| File | Purpose |
|------|---------|
| `lib/screens/psychology/psychology_schedule_form_screen.dart:204-247` | `_generateAppointments` — main logic to modify |
| `lib/models/financial_model.dart` | Add `monthlyPeriod` field if approved |
| `lib/screens/patients/tabs/treatments_tab.dart:128-172` | Displays grouped by planId + installmentNumber |
| `lib/screens/financial/collections_screen.dart` | Monthly billing will appear here naturally |
## Ver tamb�m

- [[psychology-packages]] � regras e billing
- [[psychology-kanban]] � acompanhamento dos contratos
- [[financial]] � baixa dos lan�amentos
