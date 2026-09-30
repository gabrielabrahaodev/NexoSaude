---
title: ADR 0002 — Sessão multi-tenant com SessionManager
type: adr
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - adr
  - multitenant
---

# ADR 0002 — Sessão multi-tenant com SessionManager

Fonte: [[modules/session-multitenant]].

## Contexto

Owner tem 1+ clínicas; staff restrito às suas. Toda query operacional precisa de isolamento por clínica sem `if (role)` espalhado, e o tipo da clínica (`dental` | `psychology`) muda menu, abas e profissionais.

## Decisão

`SessionManager` singleton (`ChangeNotifier`) guarda usuário + clínica atual (`setUser`, `setClinic`, `clear`, `applyFilter`, `resolveClinic`); `ClinicCapabilities` decide comportamento por tipo; `menuAccess` por usuário controla visibilidade; `allowedClinics` restringe staff; sem `clinicId`, `applyFilter` retorna query impossível (`waiting_session_init`).

## Consequências

- Isolamento centralizado; troca de clínica com `ValueKey(_currentClinicId)` força rebuild.
- Owner vê todas; staff só `allowedClinics`; auto-cadastro nasce `pending_approval` com `[]`.
- `RoleCheckScreen` roda a cada start — precisa ser rápida.

## Alternativas

- Alternativas: histórico git de lib/services/session_manager.dart tem 3 commits e não registra designs alternativos. Registrar aqui se surgirem.
<!-- fonte: git log --all --oneline -- lib/services/session_manager.dart -->

<!-- fonte: lib/services/session_manager.dart:1-18 -->
SessionManager é singleton ChangeNotifier puramente em memória (imports só de material e firestore, sem persistência). Reload perde a sessão e RoleCheckScreen re-resolve; abas não sincronizam sessão entre si, cada uma resolve a própria. O frescor dos DADOS vem dos streams do Firestore, não da sessão.

## Sincronização entre abas e reload (levantado 2026-09-30)
