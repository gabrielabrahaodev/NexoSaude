---
operonId: nx-s6
status: Planned
priority: B
tags:
  - nexosaude
  - area/financeiro
---

# S6 — Pagamentos: polimento

**Objetivo:** investigar a origem do "Sessão 1" e fechar acessibilidade e layout.
**Critério de aceite:** causa do "Sessão 1" documentada e corrigida na origem; desktop usa a largura toda; cada estado tem cor + texto + ícone. Detalhe técnico: branch `chore/pagamentos-spec-2026-09-30` (`tasks/backlog-pagamentos`, PAG-10…PAG-15).

## Tarefas

### nx-151 — PAG-10 Investigar "Sessão 1" triplicada (M)
Rastrear escrita de `title`/`description`/`installmentNumber` (wizard, pacotes mensais `monthlyPeriod`, orçamentos); corrigir na origem. Ver `[[patient-tabs]]`.
**Aceite:** causa-raiz documentada no PR + teste de regressão; timebox de 1 dia para a investigação.

### nx-152 — PAG-11 Legenda dos nós (S)
Depende de nx-150. Linha de legenda sob a barra de filtros (nó + rótulo por estado).
**Aceite:** cada cor de nó tem rótulo visível.

### nx-153 — PAG-12 Uso da área direita no desktop (M)
`LayoutBuilder`: ≥ 700px card em largura total com trilho à esquerda; mobile inalterado.
**Aceite:** screenshots 360px / 768px / 1280px no PR.

### nx-154 — PAG-13 Progresso da família inline (M)
Depende de nx-141. `2/6 pagas` + barra fina no card do pai (reaproveita `familyProgress`); toque mantém o modal.
**Aceite:** pai com filhas exibe progresso textual + barra.

### nx-155 — PAG-14 Contraste e alvos de toque (S)
Secundários em `textSecondary` do tema; alvos ≥ 44px (WhatsApp já resolvido em nx-146).
**Aceite:** nenhum alvo < 44px na timeline.

### nx-156 — PAG-15 Glifos distintos por estado (S)
Depende de nx-140. Ícone por estado no `StatusChip` (✓ pago, relógio a vencer, ⚠ vencido). Ver `[[ui-consistency]]`.
**Aceite:** cada estado tem glifo + cor + texto.
