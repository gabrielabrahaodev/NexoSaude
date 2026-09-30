---
operonId: nx-e2
status: Finished
priority: A
tags:
  - nexosaude
  - area/portal
---

# E2 — Portal do paciente e LGPD linha dura

**Objetivo:** paciente resolve a vida sem ligar (sessões, atrasos, Pix, remarcação) com consentimento LGPD à prova de auditoria.
**Critério de aceite:** sem aceite não há link nem cópia; revogar mata o acesso; aceite registrado com origem e autor.

## Entregas

- Espelhos `portal/{token}` + `portal_slots/{clinicId}` com sync por deltas (`portal_mirror.dart`, testado) — ver [[portal-mirror]]
- Pix BR Code estático local + QR (padrão Bacen, sem PSP) — ver [[pix-brcode]]
- Remarcação com aceite revalidado no vivo + recusa via WhatsApp — ver [[remarcar-dialog]]
- Checkbox LGPD no cadastro e no cadastro rápido; diálogo explícito ao gerar; `accepted/at/via/by`
- Revogação de verdade: apaga espelho + limpa token + `accepted:false`/`revokedAt`
- Sweep 09/2026: 415 espelhos sem aceite apagados, 0 restantes; autocura fechada (só `accepted==true`); backfill full travado
- Data do aceite exibida no cartão do link

## Ver também

- [[portal-page]], [[patient-details]], [[create-patient]], [[flows/atendimento|atendimento]], [[Requisitos]]
