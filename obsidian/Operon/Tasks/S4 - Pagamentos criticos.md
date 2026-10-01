---
operonId: nx-s4
status: Planned
priority: A
tags:
  - nexosaude
  - area/financeiro
---

# S4 — Pagamentos: correções críticas

**Objetivo:** a aba não mente mais sobre vencidos, valores e totais.
**Critério de aceite:** recepcionista vê o que está vencido há quantos dias, valores em pt-BR e totais que batem com a lista. Detalhe técnico: branch `chore/pagamentos-spec-2026-09-30` (`tasks/backlog-pagamentos`, PAG-01…PAG-17).

## Tarefas

### nx-140 — PAG-01 Estado VENCIDO há N dias (S)
Função pura `paymentStateOf`: `PAGO` / `VENCIDO há N dias` / `A VENCER` (inclui `dueDate == null`). Ver `[[patient-tabs]]`.
**Aceite:** chip mostra "VENCIDO há N dias" quando aplicável; borda `dueDate == hoje` testada.

### nx-141 — PAG-02 Chip só estado; parcelamento em subtítulo (M)
Depende de nx-140. Chip = só estado; estrutura vira subtítulo (`Avulso` ou `Plano • parcela X de Y`) + "N parcelas — toque para ver".
**Aceite:** nenhum chip exibe `PARCELADO` como estado; pai substituído preservado no subtítulo + modal.

### nx-142 — PAG-03 Contagem nos totais + próximo vencimento (S)
`(N lançamentos)` sob cada card + `próximo: dd/MM • R$ X` sob A RECEBER (ignora cancelados/substituídos). Resumo em `[[patient-details]]`.
**Aceite:** sem lançamentos → texto neutro, sem crash.

### nx-143 — PAG-04 Formato de moeda pt-BR (S)
`formatBRL` → `NumberFormat.currency(locale: 'pt_BR')` + atualizar `test/display_helpers_test.dart`. Ver `[[ui-consistency]]`.
**Aceite:** `formatBRL(3650)` → `R$ 3.650,00`; suite verde.

### nx-144 — PAG-17 Resumo sem conta dobrada (S)
Resumo filtra com `visibleCharges` + exclui substituídos do A RECEBER (dívida real está nas filhas).
**Aceite:** família parcelada: A RECEBER == soma das filhas não-pagas; teste puro cobre o caso.
