---
operonId: nx-e3
status: Finished
priority: A
tags:
  - nexosaude
  - area/atendimento
datetimeModified: 2026-09-29T01:23:07
---

# E3 — Atendimento e agenda operacional

**Objetivo:** rotina do profissional (meu dia → ficha → cobrança → próxima) e grade semanal confiável e legível.
**Critério de aceite:** dentista executa o dia sem sair do fluxo; bloqueios custam 1 doc; agenda abre legível nos dois temas.

## Entregas

- Modo Atendimento (`screens/care/`): Meu dia, ficha em 3 blocos, cobrança Nova/Em aberto, remarcar
- Ficha em modal 92% (`CareVisitPanel` embutível; `CareVisitScreen` virou casca) + cards translúcidos com `StatusChip` — ver [[care-day]]
- Bloqueio por intervalo: 1 doc, paciente-primeiro, fusão, idempotência (`block_interval.dart`, 14 testes) — ver [[agenda]]
- Fusão histórica: 5.638 → 270 docs (setembro Yervant 798 → 188, −76%)
- Grade: células 12px negrito adaptativo; abre na Agenda; ordem Agenda/Pacientes/Dashboard; Gestão de Agenda com scroll e intervalo personalizado
- Form dental no tema escuro; autocomplete com debounce 350ms; owner-psicólogo no espelho (`isPortalProfessional`)

## Ver também

- [[agenda-manager]], [[agenda-form]], [[portal-mirror]], [[Requisitos]]
