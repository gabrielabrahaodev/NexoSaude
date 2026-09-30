---
title: Glossário NexoSaúde
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - glossario
---

# Glossário NexoSaúde

Termos recorrentes do vault, 1 linha cada. Fonte: conteúdo existente em `PRD.md`, `modules/*`, `screens/*`, `specs/*`.

- **owner**: papel `users.role == 'owner'`; dona de 1+ clínicas, vê todas (`allowedClinics` + `ownerId`), decide financeiro e acessos.
- **tenant**: cada clínica como tenant lógico; isolamento via `clinicId` em toda query operacional (`SessionManager().applyFilter()`).
- **clinic**: unidade em `clinics/{clinicId}` (`name/type/ownerId`); `type` ∈ {dental, psychology} altera menu, abas e profissionais.
- **clinicId**: campo de isolamento multi-tenant presente em `patients`, `appointments`, `financial` e demais collections operacionais; sem ele `applyFilter` retorna query impossível (`waiting_session_init`).
- **capability**: decisão de comportamento por tipo de clínica via `ClinicCapabilities` (`isPsychology/isDental`, `canShowBudgets/Lab/Odontogram`, `canUseMonthlyPackages`, `professionalRole`, `patientTabCount`) — nunca comparar `clinicType` como string solta.
- **mirror**: cópia de leitura barata para o portal (`portal/{token}` + `portal_slots/{clinicId}`), sincronizada por `PortalMirrorSync`; consultiva, o aceite sempre revalida no vivo.
- **portal/{token}**: doc opaco por paciente (token de 32 chars revogável) com próximas 3 sessões + top-3 atrasos + totais + Pix + recusadas; `get` público, escrita por allowlist.
- **portal_slots**: doc `portal_slots/{clinicId}` com horários livres dos próximos 14 dias por dentista (`{dentistId: {data: ["HH:mm"]}}`), mantido por `arrayUnion/Remove` atômicos.
- **slot**: horário livre de 30 min da grade (08:30–20:00 na v1) dentro da janela rolante de 14 dias (semana atual + próxima).
- **pacote**: contrato recorrente `psychology_schedules` (`package`) que gera `treatment_plans` + N `appointments` + 1 `financial` por mês (`billingKind: package_monthly`).
- **sessão**: `appointment` individual; contrato `session` (avulso) gera 1 sessão só, sem recorrência, com 1 conta vencendo sessão + 7 dias.
- **oráculo**: camada de relatórios somente-leitura (`oracle_report_service`, `patient_financial_oracle`) que combina streams de `financial`/`expenses` em snapshot mensal sem escrever nada.
- **SessionManager**: singleton `ChangeNotifier` (`lib/services/session_manager.dart`) que guarda usuário + clínica atual; `setUser/setClinic/clear/applyFilter/resolveClinic`.
- **MonthAgendaCache**: cache mensal deslizante (janela anterior/atual/próxima) da agenda; semana em cache = zero leitura.
- **ensureWindow**: rotina que completa os dias faltantes da janela de 14 dias e apaga dias passados (throttle 6h via `windowBuiltAt`, 1 leitura) ao abrir a agenda / no login.
- **PackageBilling**: `lib/services/package_billing.dart`, `PackageBilling.compute` puro (sem Firebase): teto = pacote − desconto, divisor = previstas, cobrável = Realizado + falta sem atestado, parcial se mês incompleto, `paid` congela.
- **platform_debits**: débitos da plataforma por owner na aba Débitos do Master (`platform_debits` + selo aviso + baixa/dispensa), visíveis ao owner em `assinatura.html`.
- **allowedClinics**: array em `users/{uid}` com as clínicas liberadas; staff restrito a ele, auto-cadastro nasce com `[]` + `status: 'pending_approval'`.
- **clinic_capabilities**: `lib/services/clinic_capabilities.dart`; ver **capability**.
