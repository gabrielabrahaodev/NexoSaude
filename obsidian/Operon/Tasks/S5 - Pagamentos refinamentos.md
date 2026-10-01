---
operonId: nx-s5
status: Planned
priority: A
tags:
  - nexosaude
  - area/financeiro
---

# S5 — Pagamentos: refinamentos

**Objetivo:** cobrar com confiança e ler sem ambiguidade.
**Critério de aceite:** botão de cobrança rotulado, "ontem" auditável, cards na ordem de cada papel, nó nunca discorda do chip. Detalhe técnico: branch `chore/pagamentos-spec-2026-09-30` (`tasks/backlog-pagamentos`, PAG-05…PAG-09, PAG-18).

## Tarefas

### nx-145 — PAG-05 Data absoluta ao lado de "ontem" (S)
`"Último atendimento foi ontem, 29/09 (proc)."` em `[[patient-details]]` (context card).
**Aceite:** texto inclui `dd/MM`; sem histórico mantém mensagem existente.

### nx-146 — PAG-06 WhatsApp com rótulo "Cobrar" (S)
Botão rotulado (ícone + texto), altura ≥ 44px; mantém confirmação + registro no prontuário (já existem). Ver `[[patient-tabs]]`.
**Aceite:** rótulo visível em pt-BR; fluxo de confirmação preservado.

### nx-147 — PAG-07 Cores semânticas distintas (S)
Depende de nx-140. Aplica tabela da spec: `A VENCER` azul-acinzentado, `VENCIDO` vermelho; ASSIDUIDADE ganha ícone + prefixo de risco.
**Aceite:** screenshot antes/depois no PR.

### nx-148 — PAG-08 Zero em cor neutra (S)
`CUSTO OPERACIONAL R$ 0,00` em neutro; âmbar só se > 0. Ver `[[patient-details]]`.
**Aceite:** zero neutro, valor > 0 âmbar.

### nx-149 — PAG-09 Reordenar cards por papel (S)
Ordem por papel via `SessionManager`/`MenuAccess`; fallback A RECEBER primeiro para todos. Ver `[[patient-details]]`.
**Aceite:** recepcionista vê A RECEBER em 1º.

### nx-150 — PAG-18 Nó usa mesma regra do chip (S)
Depende de nx-140. Cor do nó deriva de `paymentStateOf` (fim do "chip verde, nó vermelho" no cartão). Ver `[[patient-tabs]]`.
**Aceite:** teste parametrizado: pending/pendente/cartão/substituído/cancelado.
