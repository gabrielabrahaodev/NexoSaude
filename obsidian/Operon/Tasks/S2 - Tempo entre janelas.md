---
operonId: nx-s2
status: Planned
priority: A
tags:
  - nexosaude
  - area/atendimento
---

# S2 — Tempo entre janelas

**Objetivo:** ficha e sheet abrem sem espera percebida; navegação sem ida-e-volta pelo menu.
**Critério de aceite:** ficha carrega no tempo da query mais lenta; sheet abre antes do bloco de risco; voltar da cobrança cai na ficha.

## Tarefas

### nx-128 — Cargas paralelas na ficha
Telefone + lançamentos em aberto + dentistas da ficha (`CareVisitPanel.initState`) com `Future.wait` em vez de sequência. Ver [[care-day]].
**Aceite:** tempo de abertura ≈ query mais lenta (hoje ≈ soma das 3).

### nx-129 — Sheet instantânea com shimmer
Sheet do evento na agenda (`_showAppointmentOptions`) abre na hora; só o bloco de risco (no-show) mostra shimmer até `_patientService.getPatientRiskProfile` resolver. Ver [[agenda-manager]].
**Aceite:** toque → sheet visível sem esperar risco; bloco preenche sozinho.

### nx-130 — Deep-links de volta
Cobrança e Meu dia ganham "abrir ficha/paciente" direto no contexto (sem menu lateral + recarga de listas). Ver [[collections]], [[care-day]].
**Aceite:** cobrança → ficha em 1 toque, sem perder a lista.
