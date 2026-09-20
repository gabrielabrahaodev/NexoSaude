# PRD — NexoSaúde (Controle de Clínicas)

Versão: 1.0 — 2026-09-19. Status: implementado (coberto por `Requisitos.MD`, `CASOS_DE_USO.md` UC-01..UC-91 e `docs/superpowers/specs/`). Projeto Firebase: `nexosaude` (`https://nexosaude.web.app/sistema-interno/`). Plano Spark (sem Cloud Functions).

## 1. Executive Summary

- **Problem Statement:** Clínicas de odontologia e psicologia operam agenda, prontuário, cobrança e confirmações em ferramentas desconectadas, com alta inadimplência, no-show e retrabalho da recepção; soluções prontas cobram mensalidade por usuário e não falam português operacional.
- **Proposed Solution:** Web app único (Flutter Web + Firebase) com agenda semanal/mensal, prontuário, cobrança Pix/cartão, confirmação WhatsApp, Modo Atendimento para o profissional e Portal público do paciente (confirma/remarca, vê atrasos, avisa pagamento).
- **Success Criteria:**
  - No-show cai 30% em 90 dias (confirmados / agendados, relatório mensal).
  - 100% das sessões do dia registradas (evolução + cobrança) em até 24h.
  - Leituras Firestore ≤ 40 mil/dia por clínica ativa (teto Spark 50 mil).
  - Tempo recepção por confirmação < 30s (pedido do portal → 1 toque).
  - Zero incidentes LGPD (links revogáveis, sem dado sensível em URL).
  - Baselines (no-show atual, tempo por confirmação) medidos antes do dia 0.

## 2. User Experience & Functionality

### Personas (nota de terminologia: "Modo Atendimento" = item de menu "Atendimento")

- **Owner (Dra.)**: dona de 1+ clínicas, decide financeiro e acessos.
- **Recepcionista**: agenda, confirma, cobra no balcão; volume alto.
- **Dentista / Psicólogo**: atende, registra evolução, recebe.
- **Paciente-portal**: só tem o link; confirma/remarca, vê atrasos, paga Pix.

### User Stories + Acceptance Criteria

- **US-01 (todos):** Como usuário, quero entrar com e-mail/senha ou Google, para acessar só minhas clínicas. **AC:** login nega sem `allowedClinics`; auto-cadastro nasce `pending_approval`; sessão expira no logout limpando tema/clínica.
- **US-02 (recepção):** Como recepcionista, quero agendar por célula vazia com trava de choque, para não dar double-booking. **AC:** `getBusySlots` bloqueia o submit; encaixe máx 2 por horário; bloqueio em lote gera N docs + sai dos slots livres.
- **US-03 (profissional):** Como dentista/psicólogo, quero o "Meu dia" com só meus atendimentos, para executar evolução + cobrança + próxima sessão sem trocar de tela. **AC:** lista = só hoje, só `dentistId == uid`, sem Bloqueado/Cancelado; evolução grava em `clinical_records` e finaliza; cobrança nova ou baixa de em-aberto; próxima sessão abre `wa.me` com texto padrão (sem telefone: toast + segue o fluxo).
- **US-04 (profissional):** Como psicólogo, quero o kanban Prospecto/Acompanhamento/Alta-Manutenção, para gerir o fluxo terapêutico. **AC:** drag entre estágios grava `TherapeuticStatus`; só dados da clínica (filtro `clinicId`).
- **US-05 (recepção/owner):** Como cobrança, quero WhatsApp com templates rotativos e confirmação humana de envio. **AC:** 3 templates alternados; ao voltar do WhatsApp pergunta "Você enviou?" em 100% dos envios; SIM marca como cobrado.
- **US-06 (owner):** Como dona, quero DRE/Livro Caixa mensais e antecipação de cartão, para decidir. **AC:** regime de caixa por data efetiva; Livro exporta PDF; antecipação gera taxa em despesas; valores conferem com soma manual (teste por amostragem).
- **US-07 (paciente-portal):** Como paciente com link, quero confirmar ou pedir remarcação escolhendo dia/hora livres, para não ligar. **AC:** só sessões pendentes têm botões; janela de 14 dias (semana atual + próxima) filtrada pelo dentista da sessão; proposta grava `remarcar` + data e vira pendência; recusada some da minha lista e segue livre pros demais; sem telefone cadastrado o fluxo degrada pra balcão (aviso explícito, sem travar a tela).
- **US-08 (paciente-portal):** Como paciente, quero ver só meus atrasos e pagar via Pix, para quitar sem balcão. **AC:** seção lista só `dueDate < hoje` não-quitados (top 3 + totais); toggle mostra QR + código BR Code gerados localmente (grátis, sem PSP); "Avisei que paguei" por débito gera selo na Cobrança.
- **US-09 (recepção/dentista):** Como equipe, quero decidir remarcações e avisos numa caixa única, para nada se perder. **AC:** selo na agenda + card no Meu dia; aprovar revalida choque no vivo; recusar abre WhatsApp pronto; aviso vira selo dispensável.
- **US-10 (owner):** Como dona, quero gerenciar acessos, tema e Pix sem código. **AC:** `menuAccess` por usuário (owner ignora); tema por usuário com fallback claro; `pixKey` só owner escreve; token do portal gera/copia/revoga na aba Cadastro (revogar mata o link; link revogado retorna "inválido" em até 60s); excluir paciente apaga o espelho (cascata); aceite LGPD no cadastro (sem aceite, sem token).
- **US-11 (superadmin):** Como dono da plataforma, quero gerenciar owners, trials e débitos. **AC:** seção Master só com `role=superadmin`; bloquear/liberar por clínica; gerar mensalidade `40+15×(n−1)` com vencimento +30d; novo owner+trial 7d em 1 fluxo; trial expirado ou bloqueio manual barra o login com tela explicativa.
- **US-12 (owner):** Como dona, quero ver minha assinatura fora do operacional. **AC:** página `assinatura.html` (mesmo login): plano, débitos com Pix e aviso individual; sino de pendências no menu (remarcar/avisos, profissional vê só os seus).

### Non-Goals

- App mobile nativo (só web responsivo); automação de WhatsApp agendado; grade de horários configurável; prontuário editável pelo portal; multi-idioma; cobrança recorrente automática (sem backend no Spark).

## 3. AI System Requirements

Não aplicável (sem IA no produto). Mantido o slot do schema por conformidade.

## 4. Technical Specifications

### Architecture Overview

Flutter Web (release em `/sistema-interno/`, páginas públicas `anamnese.html`, `confirmar.html`, `portal.html` na raiz do hosting) + Firebase (Auth, Firestore, Hosting). Fluxos: telas → services (`AppointmentService`, `FinancialService`, `ClinicalRecordService`, `PortalMirrorSync`, `RemarcacaoService`, `MonthAgendaCache`) → Firestore. Helpers puros testados em `lib/utils/display.dart` (`parseBRL`, `formatBRL`, `formatDate*`, `toast`, cores). Sem backend: toda automação é clique no app ou escrita pública com allowlist.

### Integration Points

- **Auth:** e-mail/senha + Google (`google_sign_in`, popup web); 6 contas migradas com hash (senhas redefinidas via `reset-senha.bat`).
- **DB:** collections `appointments`, `patients`, `financial`, `expenses`, `clinical_records`, `users`, `clinics`, `portal`, `portal_slots`, `password_reset_requests`, `suppliers`, `procedures`, `lab_orders`, `budgets`, `treatments`.
- **Espelhos do portal:** `portal/{token}` (3 sessões + top-3 atrasos + totais + Pix + recusadas) e `portal_slots/{clinicId}` (livres 14 dias por dentista, `arrayUnion/Remove` atômicos); `syncPortalMirror()` nos pontos de escrita; janela varrida no login.
- **Pagamentos:** `recordingFor(method)` define pago/pendente; Pix/cartão com taxas por perfil de máquina; antecipação com taxa em despesas.
- **Documentos/imagens:** upload unsigned para **Cloudinary** (`dbbh601ay`, `resource_type: auto`); metadados em `patients/{id}/docs`; exclusão apaga só metadados (Spark sem Functions; binários órfãos com limpeza manual). Custo/limite Cloudinary fora do free tier Firebase — monitorar.

### Security & Privacy

Rules escopadas por `clinicId` (owner.full); `settings/integrations` só owner; `user_prefs` próprio/owner; anamnese allowlist de 14 campos; `password_reset_requests` create público + resto owner; portal `get` público (doc opaco) + updates por allowlist (`statusSessao`, `pedidoRemarcacao`, `avisoPagamento`, `propostasRecusadas` via app); `appointments` público só `Confirmado`/`remarcar` (+ data/token); `financial` público só `avisoPagamento`. Tokens de 32 chars revogáveis; aceite LGPD no cadastro (responsabilidade do owner); e-mails genéricos sem caixa (reset via `.bat`, nunca por e-mail).

## 5. Risks & Roadmap

- **Phased Rollout:** MVP (agenda+pacientes+financeiro base) → v1.1 (Modo Atendimento) → v1.2 (Portal + pendências) → v1.3 (polish web-designer: tema, consistência, cota) → v1.4 (plataforma: landing, Master, Assinatura, trials, Pix BR Code). Estado atual: v1.4 em `master`/`web-designer`.
- **Technical Risks:**
  - **Cota Spark (50 mil leituras/dia):** mitigado com queries mensais/diárias limitadas, cache mensal da agenda, espelhos de 1 doc; monitorar Uso; saída = Blaze com orçamento US$ 1.
  - **Deriva de espelhos:** escrita esquecida mente no portal; mitigado por helper único + aceite sempre revalida no vivo + backfills em `migrate/`.
  - **Senhas da migração:** hashes importados não bateram; mitigado com redefinição via Admin SDK + fluxo sem e-mail.
  - **Link vazado:** token longo + revogação 1-clique + espelho mínimo (sem histórico).
