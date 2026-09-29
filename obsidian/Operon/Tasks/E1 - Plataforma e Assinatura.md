---
operonId: nx-e1
status: Finished
priority: A
tags:
  - nexosaude
  - area/plataforma
---

# E1 — Plataforma e Assinatura

**Objetivo:** transformar o app odontológico em produto multi-clínica assinável (trial, cobrança por usuário, páginas públicas).
**Critério de aceite:** owner contrata sozinho pelo site; trial expira e trava; Master opera owners/débitos/trials.

## Entregas

- Trial com porteira: cadastro → pendente → Master aprova → relógio de 7d anda (`web/assinatura.html`, `web/master.html`, rules A1b, `trial_requests`)
- Páginas públicas: [[landing-page]], [[assinatura-page]], [[master-screen]] (+ `logo.png` na raiz, landing vira `index.html`)
- Trava de assinatura (`subscription.dart`: 40+15×(n−1), trial OU bloqueio manual) em `role_check_screen`
- Débitos da plataforma (`platform_config/debits`, rules dedicadas) + gerar mensalidade + novo owner
- Deploy hosting + 51 índices (`firestore.indexes.json` como fonte da verdade)
- Suite ~76 testes verdes na entrega (menos `widget_test` do baseline)

## Ver também

- [[spec-landing-master]], [[PRD]], [[Requisitos]], [[CASOS_DE_USO]]
