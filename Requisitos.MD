# OdontoControle - Requisitos & Regras de Negócio

Documento de regras de negócio extraídas do código-fonte. Cada regra referencia o arquivo de origem (`lib/`) para rastreabilidade. Este documento serve como fonte de verdade para implementações, correções e testes.

**Papel responsável pela coleta:** 👨‍💻 Tech Lead / Senior Dev (execução e precisão técnica).

---

## Sumário

1. [Autenticação, Roles e Multi-tenancy](#1-autenticacao-roles-e-multi-tenancy)
2. [Agenda e Agendamentos](#2-agenda-e-agendamentos)
3. [Pacientes](#3-pacientes)
4. [Anamnese e Prontuário](#4-anamnese-e-prontuario)
5. [Odontograma](#5-odontograma)
6. [Orçamentos e Tratamentos](#6-orcamentos-e-tratamentos)
7. [Financeiro (Receitas, Despesas, Cobranças)](#7-financeiro)
8. [Psicologia (Pacotes e Fluxo Terapêutico)](#8-psicologia)
9. [Laboratório](#9-laboratorio)
10. [Gestão (Clínicas, Funcionários, Operações)](#10-gestao)
11. [Fluxos Públicos e Leads](#11-fluxos-publicos-e-leads)
12. [Regras de Segurança Firestore](#12-regras-de-seguranca-firestore)
13. [Integração WhatsApp](#13-integracao-whatsapp)
14. [Documentação de Arquivos](#14-documentacao-de-arquivos)

---

## 1. Autenticação, Roles e Multi-tenancy

### RN-01 - Roles do sistema
- Roles existentes: `owner` (proprietário), `recepcionista`, `dentista`, `psicologo`, `gerente`.
- Referência: `screens/auth/login_screen.dart:67-72`, `services/user_service.dart`, `AGENTS.md`.

### RN-02 - Registro de novo usuário
- Novo usuário escolhe role (dentista/recepção) no cadastro.
- Nasce com `allowedClinics: []` + `status: 'pending_approval'` — **sem acesso até o owner liberar** em Funcionários.
- **Entrar com Google** (popup Web / conta do aparelho mobile): estreante ganha o mesmo doc pendente (`authProvider: 'google'`); email já cadastrado com senha → orientado a usar senha.
- Auto-cadastro liberado na rule (só o próprio doc, role não-owner, sem clínica, pendente).
- Reset sem e-mail (e-mails genericos, sem caixa de entrada): "Esqueci a senha?" no login grava pedido em `password_reset_requests` (create publico, rule A3); responsavel gera a temporaria com `migrate/reset-senha.bat` (`reset-password.js` + Admin SDK) e informa a pessoa; pedidos visiveis em Funcionarios (só owner) com copiar/dispensar. Troca de senha no cartao "Minha conta" em Gestao > Configuracoes com re-autenticacao (`reauthenticateWithCredential` + `updatePassword`, min. 6).
- Referência: `login_screen.dart`.

### RN-03 - Visibilidade por role
- **Owner**: vê todas as clínicas via seletor; acessa menus Clínicas e Funcionários.
- **Staff** (recepcionista, dentista, psicologo, gerente): restrito a `allowedClinics`.
- **Gestão** (aba Gestão): owner ou recepcionista.
- Financeiro, Relatórios, Cobranças, Notícias e Laboratório: **sem guard de role no código** — isolamento efetivo via regras Firestore.
- Referência: `screens/dashboard/main_web_dashboard.dart:289-331`.

### RN-04 - Filtro multitenant (`applyFilter`)
- Toda query operacional DEVE passar por `SessionManager().applyFilter()`:
  - Owner com `clinicId == 'ALL'` ou `null` → sem filtro (vê tudo).
  - `clinicId == null` (staff) → query com `clinicId == 'waiting_session_init'` (resultado vazio, evita erro de permissão).
  - Demais → `clinicId == currentClinicId`.
- Referência: `services/session_manager.dart:48-59`.

> ✅ **Resolvido:** `getAllStream`, `getPatientRiskProfile`, `getByPatientId`, `getPlansStream`, `lab.getByPatient`, queries do smart-card e da aba Pagamentos agora aplicam `applyFilter`/filtro `clinicId`. Restam sem filtro: `product_service` (legado), leituras de gestão (`procedures` é global por desenho). Índices compostos em `firestore.indexes.json` (deploy pendente).

### RN-05 - Tipo de clínica controla a UI
- Campo `clinicType` da clínica (`dental` | `psychology` | outros).
- **Proibido comparar `clinicType` solto no código** — usar `ClinicCapabilities` (`isPsychology`, `canShowBudgets/Lab/Odontogram`, `canUseMonthlyPackages`, `professionalRole`, `patientTabCount`).
- Menu "Fluxo Terapêutico" só aparece para `psychology` (telas "Novos Leads" e "Agendas Psicologia" foram removidas do menu).
- Abas do paciente variam por tipo: **dental = 9 abas**, **psicologia = 6** (sem ORÇAMENTOS/ODONTOGRAMA/LABORATÓRIO).
- Referência: `services/clinic_capabilities.dart`, `main_web_dashboard.dart`, `screens/patients/patient_details_screen.dart`.

### RN-06 - Troca de clínica (owner)
- Seletor busca `clinics where ownerId == user.uid`.
- Ao trocar: `SessionManager().setClinic(id, name, type)` + rebuild de telas via `ValueKey(_currentClinicId)`.
- Se nenhuma clínica selecionada, auto-seleciona a primeira.
- Referência: `main_web_dashboard.dart:102-199`.

---

## 2. Agenda e Agendamentos

### RN-07 - Ciclo de status do agendamento
```
Aguardando Confirmação → Confirmado → Finalizado (+ attendanceStatus)
                                  ↘ Cancelado (+ metadados)
Bloqueado (agendamento sintético)
```
- Referência: `models/appointment_model.dart:30-32`, `widgets/appointment_cards.dart`.

### RN-08 - Duração da consulta
- Múltiplos de 30 min: usuário seleciona N horários → `durationMinutes = N * 30`.
- Células ocupadas na grade: `ceil(durationMinutes / 30)`.
- Referência: `screens/agenda/agenda_form_screen.dart:420-489`, `screens/agenda/agenda_manager_screen.dart:961-981`.

### RN-09 - Verificação de disponibilidade
- Horários ocupados ignoram: o próprio agendamento em edição (`excludeId`) e status `Cancelado`.
- Comparações de status são **case-insensitive** nos leitores críticos (billing, `getBusySlots`, risco, `isCancelled/isDone`, cancelamento de contrato); o form já normalizava com `toLowerCase()`.
- Referência: `services/appointment_service.dart:33`, `package_billing.dart`, `models/appointment_model.dart:43-44`.

### RN-10 - Encaixe (2º paciente no mesmo horário)
- Permitido apenas quando há **1 evento ativo** no slot (`concurrentCount == 1`).
- Máximo de **2 pacientes por horário**; sem possibilidade de 3º encaixe.
- Referência: `agenda_manager_screen.dart:435-436,580-596`.

### RN-11 - Restrição por profissional
- Dentista visualiza **apenas seus agendamentos** (`dentistId == user.uid`); recepção/owner filtram por dropdown de dentista.
- Referência: `agenda_manager_screen.dart:937-951`.

### RN-12 - Bloqueio de horários
- Bloqueios criados como `AppointmentModel` sintético: `patientId='BLOCKED_SLOT'`, `patientName='BLOQUEADO'`, `status='Bloqueado'`, `durationMinutes=30`.
- Faixas: Manhã 08–12h, Tarde 13–18h, Dia Todo 08–20h (via WriteBatch).
- Liberar dia: deleta todos `status='Bloqueado'` do intervalo (respeita filtro de dentista).
- Referência: `agenda_manager_screen.dart:99-273`.

### RN-13 - Cancelamento com motivo
- Origem obrigatória: `Paciente` ou `Clínica/Dr(a)`.
- Motivo obrigatório (bloqueia se vazio).
- Grava: `status='Cancelado'`, `cancelledBy`, `cancellationReason`, `cancellationSource`, `cancelledAt`.
- **Cria registro clínico** "Cancelamento de Consulta" com origem/motivo.
- Referência: `agenda_manager_screen.dart:308-410,600-607`.

### RN-14 - Finalizar atendimento
- Só a partir de `Confirmado`.
- **Realizado (dental)**: exige plano ativo + procedimento do plano + evolução obrigatória; cria registro clínico; `status='Finalizado'` + `attendanceStatus='Attended'`.
- **Realizado (psicologia)**: sem dropdown de procedimento — usa o vínculo do pacote (`planId`) e o `procedure` do agendamento; só a descrição.
- **Não Compareceu**: motivo opcional + checkbox **Apresentou Atestado**; cria registro "Paciente Não Compareceu" (+ "Apresentou atestado."); `attendanceStatus='Missed'` + `hasMedicalCertificate`.
- Dentista não encontrado no doc → fallback `'Dr(a). Responsável'`.
- Referência: `agenda_manager_screen.dart` (`_showFinishAppointmentDialog`).

### RN-15 - Confirmação via WhatsApp
- Link público `https://odontocontrole-1c701.web.app/confirmar.html?id=<apptId>` permite update de status para `'Confirmado'`.
- Pré-requisito: telefone do paciente com ≥10 dígitos e prefixo DDI `55`.
- Referência: `agenda_manager_screen.dart:277-306,546-554`, `firestore.rules`.

### RN-16 - Perfil de risco de no-show (classificação)
- Base: últimos **20 agendamentos** do paciente.
- Falta = `attendanceStatus=='Missed'` **sem atestado** (`hasMedicalCertificate != true`) **ou** (`status=='Cancelado'` **e** `cancellationSource=='Paciente'`).
- Classificação: `taxa >= 0.3` **ou** `faltas >= 3` → **vermelho**; `taxa >= 0.1` → **amarelo**; senão **verde**.
- Sem histórico ou erro → retorna `{green, 0}` (fail-safe).
- Referência: `services/patient_service.dart:28-60`.

### RN-17 - Agendamento psicologia (na agenda)
- Célula vazia em clínica `psychology` → `AgendaCellFactory.openForm` abre o formulário com data/dia/hora **travados** (vindos da agenda).
- Duração de sessão de psicologia: **60 min** (2 slots de 30 na grade).
- Referência: `screens/agenda/agenda_cell_factory.dart`, `psychology_schedule_form_screen.dart`.

---

## 3. Pacientes

### RN-18 - Campos obrigatórios e validações (cadastro)
- Nome obrigatório; telefone com máscara `(##) #####-####` e ≥14 dígitos; CPF obrigatório.
- Psicologia: dropdown de Status Terapêutico (default Prospecto; grava `lead/active/discharged`). Dental: sem campo, grava `status='Ativo'` (lista não depende do campo).
- Verificação de CPF duplicado por clínica (query existe; **bloqueio está comentado no código**).
- Referência: `screens/patients/create_patient_screen.dart:82-127,148-191`.

### RN-19 - Dados derivados
- `searchKey` = nome em minúsculas (usado em buscas autocomplete).
- `status='Ativo'` padrão; `createdAt` serverTimestamp.
- Referência: `create_patient_screen.dart:99-110`.

### RN-20 - Exclusão em cascata (atômica)
- Batch único (blocos de 450) deleta na ordem: appointments → budgets → treatments → treatment_plans → financial → clinical_records → lab_orders → psychology_schedules → subcoleções (`clinical_data`, `docs`) → `anamnesis/{patientId}` (top-level) → o próprio paciente. `purgePatientFiles` roda após o commit.
- Referência: `services/patient_service.dart:79-153`.

### RN-21 - Parsing defensivo
- `address` aceita String **ou** Map; `birthDate` aceita String **ou** Timestamp; `createdAt` aceita Timestamp/String/fallback `now`.
- Referência: `models/patient_model.dart:30-95`.

---

## 4. Anamnese e Prontuário

### RN-22 - Anamnese
- Persistida em `anamnesis/{patientId}` (write público via link — regra Firestore).
- Formulário: estado geral (tratamento, medicação, alergias), histórico patológico (Diabetes, Hipertensão, Cardíacos, Renais, Gástricos, Respiratórios, Hepatite, HIV, Anemia, Coagulação), hábitos (fumante, álcool, bruxismo, gestante) e observações.
- Salvar = `set()` completo (sobrescreve doc).
- Referência: `screens/patients/tabs/anamnesis_tab.dart:64-321`.

### RN-23 - Registros clínicos (prontuário)
- Todo registro exige: tratamento ativo (opcional vincular), procedimento e descrição obrigatória.
- Grava `dentistName` (da sessão; fallback `'Dr(a).'`).
- Cancelamento de consulta e finalização de atendimento geram registros automaticamente.
- Referência: `screens/patients/tabs/clinical_record_screen.dart:34-165`.

---

## 5. Odontograma

### RN-24 - Estrutura
- Dentição padrão adulta de **32 dentes** em 4 quadrantes.
- Persistido em `patients/{id}/clinical_data/odontogram`.
- Referência: `screens/patients/tabs/odontogram_screen.dart:26-83`.

### RN-25 - Estados e regras de conflito de faces
- Estados: Saudável, Cárie/Lesão, Restaurado, A Realizar, Extrair, Coroa (planejada/realizada), Implante (planejado/realizado), Endodontia (planejada/realizada).
- Regras:
  - **Implante realizado** limpa as demais faces e **bloqueia ações** nas faces.
  - **Coroa realizada** limpa faces que não sejam raiz/oclusal e bloqueia ações padrão na oclusal.
  - **Extração** marca todas as faces como `missing`.
  - **Saudável** remove o status.
- Referência: `odontogram_screen.dart:85-153`.

---

## 6. Orçamentos e Tratamentos

### RN-26 - Orçamento (budget)
- Status: `Pendente` → `Aprovado` (via wizard).
- Composto de itens (id de procedimento, categoria, nome, preço) + total.
- Não é possível salvar sem itens.
- Referência: `screens/patients/tabs/budgets_tab.dart:28-279`, `models/budget_model.dart`.

### RN-27 - Aprovação de orçamento (geração de financeiro)
- Se algum item tem `generatesMonthlyFee == true` → ativa fluxo de **mensalidades** (padrão 12x, primeiro vencimento escolhido) e captura **custo automático** do procedimento.
- Gera recebíveis: N mensalidades (`i/N`) + 1 receita por item do orçamento.
- Gera despesa "Custo Inicial" quando há custo.
- Sem procedimento ortodôntico → pula etapa de mensalidade.
- Referência: `screens/patients/wizards/budget_approval_wizard.dart:45-318`.

### RN-28 - Plano de tratamento
- Criado na aprovação com: itens do orçamento (status `pendente`), `totalValue`, `status='active'`, `budgetId`, `type` da clínica.
- `closePlan` → `status='completed'`.
- Financeiro do plano vinculado por `planId`; despesas por `relatedPlanId` ou `relatedFinancialId`.
- Referência: `services/treatment_service.dart:33-96,25-27`.

### RN-29 - Raio-X financeiro do tratamento
- Margem = recebido − custos lab − repasses; progresso = recebido/total.
- Parcelas pagas/total calculadas por `installmentNumber`.
- Referência: `screens/patients/tabs/treatments_tab.dart:159-175`.

---

## 7. Financeiro

### RN-30 - Tipos e status
- `type`: `income` (receita) / `expense` (despesa).
- `status` de receita: `pendente`/`pending`, `pago`/`paid`, `cobrado`, `anticipated`, `cancelado`, `pago (renegociado/parcelado)` (legado pode ter maiúsculas — leitores comparam lowercase).
- `status` de despesa: `pendente` / `pago`.
- `isPaid` = **definição única** `FinancialModel.isPaidOf` (qualquer caixa: paid/pago/quitado/anticipated/antecipado/recebido, ou `paidAmount >= amount > 0`; + flag crua `isPaid==true` nos leitores de mapa). Timeline soma exceção de cartão-pendente (tesouraria). Teste: `financial_ispaid_test`.
- Convenção p/ escrita nova: status financeiro **sempre minúsculo** (`pendente/pago/cancelado/...`); leitura de mapas crus compara lowercase. `isPaid` tem 4 implementações (getter do model, mágica da timeline p/ cartão, `_isPaid` do KPI, listas dos reports) — regra: model novo usa o getter; mapa cru usa lista lowercase.
- Campos gêmeos (legado, não apagar por compat): `valorLiquido`/`netAmount` (sempre iguais), `paidDate`/`paymentDate`; docs novos podem gravar só um lado (`valorLiquido`, `paymentDate`).
- Referência: `models/financial_model.dart:65`, `screens/financial/collections_screen.dart:172-196`.

### RN-31 - Pagamento à vista
- Condição: `payValue >= (amount - paidAmount)` **e** `installments == 1`.
- `paymentDate`/`date` padrão = `FieldValue.serverTimestamp()` (não relógio do aparelho).
- Atualiza o título original: `isPaid`, `status`, `paymentDate`, `paymentMethod`, `paidAmount`, `payerName/Cpf`, `dentistId/Name`, `feePercentage`, `taxVal`, `valorLiquido`/`netAmount`.
- Referência: `services/financial_service.dart:59-78`.

### RN-32 - Pagamento parcelado (renegociação)
- Atualiza original com `status = '<status> (renegociado/parcelado)'` (minúsculo).
- Cria N lançamentos filhos: `dueDate = now + 30*i` (**blocos de 30 dias corridos, não meses de calendário** — regra mantida), `installmentNumber = 'i/N'`, `parentId` = id da original, `paidAmount` cheio, `description '<título> (i/N) - método'`.
- **Ajuste de centavos**: diferença entre `payValue` e soma das parcelas vai para a **1ª parcela** (bruto e líquido) — `computeInstallments` puro e testado.
- Cancelar oferece **só este / família toda** (irmãs pelo `parentId` + original).
- Cartão parcelado → **deleta o título original** e grava `machineProfileId`.
- Referência: `financial_service.dart:computeInstallments/processPayment`, `patient_financial_tab.dart:_confirmCancelCharge`.

### RN-33 - Pagamento parcial (REMOVIDO)
- ~~`payment_service.receivePayment` ("(Restante)")~~ — método morto, sem chamadores; removido. Parcial se resolve via estorno + relançamento ou valores no wizard.

### RN-34 - Parcelamento "explosão" D+30 (REMOVIDO)
- ~~`payment_service` transformava original em `1/N`~~ — morto junto com o método acima. Parcelamento vive em `processPayment` (RN-32).

### RN-35 - Estorno (receita/despesa)
- Receita: `isPaid=false`, `paidAmount=0`, remove `paymentDate`/`paymentMethod`, `status='pendente'` → valor volta ao saldo devedor.
- Despesa: `status='pendente'`, remove `paidDate`.
- Antes do estorno, deleta despesas/lab_orders vinculados (`relatedFinancialId`).
- No dialog de estorno há **CORRIGIR E RELANÇAR**: estorna e reabre o recebimento pré-preenchido (método + valor).
- Referência: `services/financial_service.dart:21-34`, `payment_service.dart:104-122`, `patient_financial_tab.dart:110-201`.

### RN-35b - Cancelar / editar / recriar lançamento
- Toque no item abre **menu por estado** (sem long-press): pendente = Receber/Editar/Cancelar; pago = Estornar-Corrigir/Cancelar; cancelado = Recriar.
- **Editar pendente**: valor/vencimento in place (sem mexer em quitação/vínculos).
- **Recriar cobrança**: form pré-preenchido (valor/vencimento editáveis) → pendente nova clonada; vínculos travados como info; aviso se parcela tem irmãs.
- Referência: `financial_service.dart:cancelCharge/recreateCharge/recreatedData/editPendingCharge`, `patient_financial_tab.dart:_showItemOptions/_confirmCancelCharge/_confirmRecreateCharge/_showEditPendingCharge`.

### RN-36 - Livro-caixa (regime de caixa)
- **Receita**: cartão → considera `dueDate` (entra no mês do vencimento); se antecipada → `paidDate` + `isPaid=true`; outros métodos → `paidDate` se paga, senão `dueDate`.
- **Despesa**: `paidDate` se paga, senão `dueDate`.
- Saldo acumulado considera **todos** os itens (pagos ou não): `+receita / −despesa`.
- Referência: `services/oracle_report_service.dart:79-199`.

### RN-37 - Despesas (contas a pagar)
- Categorias: Custos Fixos, Manutenção, Impostos, Marketing, Outros.
- Classificação visual do card: VENCIDO (<0 dias), VENCE EM BREVE (≤2 dias), EM ABERTO, PAGO.
- Baixar pagamento → `status='pago'` + `paidDate`.
- Referência: `screens/financial/expenses_screen.dart:234-254`, `services/expense_service.dart:69-74`.

### RN-38 - Despesa recorrente/parcelada
- Batch cria N docs: `dueDate` avançando 1 mês, `description '(i/N)'`, `installmentNumber`, `recurrenceId` (timestamp ms), `status='pendente'`.
- Exige clínica selecionada (senão exceção).
- Referência: `expense_service.dart:23-66`.

### RN-39 - Antecipação de recebíveis
- Elegíveis: receitas `income` de cartão, não canceladas, não antecipadas, com `dueDate` não expirado.
- Taxa mensal: `clinics/{clinicId}/settings/fees.anticipation_rate` (default **2,29%**).
- Cálculo: meses = `ceil(days/30)` (mínimo 1); taxa = `valor * (rate/100) * meses`.
- Gravação (batch): despesa "Taxa de Antecipação de Recebíveis" (paga) + parcelas totais `status='anticipated'` ou parciais (`isPartialAnticipation=true`, `originalDocId`, reduz `amount` do original).
- Referência: `screens/reports/reports_screen.dart:416-651`.

### RN-40 - Cobranças (WhatsApp manual)
- Consulta: `status whereIn ['pendente','pending']`, `type='income'`.
- Modo pacotes (só psico): `monthlyPeriod` do mês. Modo Por Sessão: `dueDate` no mês **excluindo** pacotes (`billingKind`/`monthlyPeriod`).
- Pacote mensal: pacote completo (baixa tudo) ou parcial (só registra contato); valor = `PackageBilling` ao vivo com `BillingSkeleton` (timeout 5s); congela no `paid`.
- Marcar cobrada: `status='cobrado'`, `lastContactDate=serverTimestamp`, `contactHistory += {date, method:'whatsapp_manual'}`.
- Confirmação humana: SIM marca (individual ou pacote); **NÃO = no-op puro** (zero escrita, item segue pendente e visível p/ cobrar de novo).
- Badge "Já contatado hoje" se `lastContactDate == hoje`.
- Referência: `screens/financial/collections_screen.dart`, `services/package_billing.dart`.

### RN-40b - Ficha do paciente: cabeçalho e aba Pagamentos
- Cabeçalho com 4 cards: assiduidade, A Receber (valor−pago), Recebido, Custo Operacional (`expenses` por `relatedPatientId`).
- Aba Pagamentos sem cards: filtros em bottom sheet (valor mín/máx, procedimento) + toggle de ordenação (padrão: vencimentos próximos).
- Referência: `patient_details_screen.dart` (`_HeaderSummaryRow`), `patient_financial_tab.dart`.

---

## 8. Psicologia

### RN-41 - Tipos de agenda psicologia
- `package` (Pacote) vs `session` (Sessão Avulsa).
- Referência: `models/psychology_schedule_model.dart:40-60`.

### RN-42 - Geração de sessões
- **Pacote**: semanal da data de início até **31/12 do ano de início**.
- **Avulsa**: **1 sessão só**, na data/hora selecionada (sem recorrência).
- Dia da semana mapeado de pt-BR (default Segunda).
- Cada sessão vira: item do `treatment_plans` (status `pendente`), `appointment` (60min, "Aguardando Confirmação") com `scheduleId/planId/monthlyPeriod`.
- Referência: `models/psychology_schedule_model.dart`, `psychology_schedule_form_screen.dart` (`_generateAppointments`).

### RN-43 - Financeiro do agendamento
- **Pacote**: 1 registro por mês (`monthlyPeriod: "YYYY-MM"`, `billingKind: package_monthly`); valor cheio do pacote; `dueDate` = dia 10 do mês seguinte; `installmentNumber='Jan/2025 1/5'`.
- **Avulsa**: 1 registro por sessão (`billingKind: session`); `dueDate = data da sessão + 7 dias`; `installmentNumber='i/N'`.
- **Valor efetivo** = valor do pacote (ou sessão) − `thirdPartyDiscount` (desconto entra **antes** do rateio).
- **Billing por presença** (decisões travadas: parcial, divisor = previstas, atestado abate, desconto antes): `PackageBilling.compute` — cobrável = Realizado + falta sem atestado; congela no `paid`. Ver `PSYCHOLOGY_PACKAGES.md`.
- Referência: `services/package_billing.dart`, `psychology_schedule_form_screen.dart`.

### RN-44 - Edição e cancelamento de contrato
- **Edição não regenera sessões** (só atualiza o schedule; só o `add` gera).
- **Cancelamento implementado** (botão no modo edição do form, `_confirmCancelSchedule`/`_cancelSchedule`): dialog de escopo → `psychology_schedules` vira `cancelled`; appointments futuros não finalizados → `Cancelado`; financeiros `pendente/pending` do plano → `Cancelado`; finalizados/pagos intactos; batch em blocos de 450.
- Referência: `psychology_schedule_form_screen.dart:327-425`.

### RN-45 - Fluxo terapêutico (Kanban)
- Estágios: `lead` (Prospecto) → `active` (Acompanhamento) → `discharged` (Alta-Manutenção), em `patients.status` (arrastar no kanban grava direto).
- **Lead → Active** exige checklist: Contrato Terapêutico, Anamnese Inicial, Dados de Faturamento (LGPD/HIPAA); grava `treatment_start_date`.
- **Active → Discharged** exige **motivo obrigatório**; grava `discharge_reason` + `discharge_date`.
- `lead → active` e `active → discharged` sempre passam por dialog; outros movimentos são diretos.
- Referência: `screens/patients/psychology/psychology_kanban_board.dart:275-392`.

---

## 9. Laboratório

### RN-46 - Ciclo de status da ordem
```
Solicitado (pending_send) → Enviado (sent, sentDate) → Devolução (pending_return, returnDate) → Entregue (delivered, deliveredDate)
```
- Interações (Problema/Atraso) adicionadas via `arrayUnion` (somente pedidos enviados).
- Referência: `widgets/lab_kanban_board.dart:54-148`, `services/lab_service.dart:37-47`.

### RN-47 - Pedido manual
- Exige descrição; vincula tratamento (opcional) e solicitante; `status='pending_send'`.
- Referência: `screens/patients/tabs/patient_lab_tab.dart:26-143`.

---

## 10. Gestão

### RN-48 - Clínicas
- Tipos: Odontológica, Psicológica, Fisioterapêutica, Estúdio de Ioga.
- Criação adiciona a clínica ao `allowedClinics` do owner (`arrayUnion`).
- Referência: `screens/clinics/clinic_management_screen.dart:15-134`.

### RN-49 - Funcionários
- Cadastro usa **FirebaseApp temporário** para criar auth do funcionário (risco: pode deslogar o admin atual).
- Grava `users/{uid}` com role, `allowedClinics:[clinicId]`, `status='Ativo'`.
- Owner escolhe a clínica; staff usa a clínica atual.
- Referência: `screens/employees/employee_manager_screen.dart:33-209`.

### RN-50 - Busca de profissionais por tipo de clínica
- Psicologia → `psicologo` | `owner`; Odontologia → `dentista` | `owner`.
- Filtra por `allowedClinics` contendo a clínica; owner sempre incluso.
- Referência: `services/user_service.dart:13-53`.

### RN-51 - Estoque
- `isLowStock`: `currentQty <= minQty` → alerta "REPOR ESTOQUE".
- Ajuste rápido ±1 via `FieldValue.increment` (atômico).
- Referência: `screens/operations/tabs/inventory_tab.dart:15-168`, `services/inventory_service.dart:10-32`.

### RN-52 - Procedimentos
- Repasse: tipo `percent` ou fixo (`commissionType`, `commissionRate`).
- Switches: "Gera Custos/Despesas?" (ex.: laboratório) e "Gera Mensalidade?" (ex.: manutenção orto 12x).
- Referência: `screens/operations/tabs/procedures_tab.dart:16-175`, `models/procedure_model.dart:17-28`.

### RN-53 - Fornecedores
- Categorias: Laboratório de Prótese, Dentista Parceiro, Materiais de Consumo, Manutenção, Serviços Gerais, Impostos/Taxas.
- `isProfessional` = "É Dentista da Equipe?" → recebe comissão/repasse.
- Referência: `screens/operations/tabs/suppliers_tab.dart:27-98`.

### RN-54 - Tarifas de cartão (perfis de máquina)
- Perfis em `clinics/{id}/settings/fees/profiles`.
- Config: taxa débito, crédito à vista, **faixas de parcelamento** (De/Até/Taxa, ordenadas por `from`) e **taxa de antecipação** mensal.
- `activeProfileId` define o padrão; primeiro perfil criado vira padrão; excluir o padrão o redefine para null.
- Referência: `screens/operations/tabs/card_fees_tab.dart:60-529`.

### RN-54b - Aba Configurações (tema + acesso)
- 5ª aba da Gestão: **Aparência** (claro/escuro = preferência do usuário em `user_prefs/{uid}`, vale em qualquer aparelho; sem preferência = claro; logout mantém o último tema na tela de login) e **Controle de acesso** (só owner).
- Acesso: `users/{uid}.menuAccess` (Map chave→bool; ausente = tudo visível); `MenuAccess.canShow` filtra o menu; `keysForClinicType` esconde do controle o que o tipo não mostra (psico: sem laboratório; dental: sem fluxo); owner ignora restrições; tela escondida com seleção ativa cai p/ Dashboard.
- `AppColors` adaptativo (6 cores via getter); telas com cor hardcoded não seguem o escuro (fase 2).
- Referência: `screens/operations/tabs/settings_tab.dart`, `services/theme_controller.dart`, `services/menu_access.dart`, `services/user_service.dart:watchClinicUsers/updateMenuAccess`.

---

## 11. Fluxos Públicos

### RN-55 - Avaliação digital (rota /avaliacao)
- `cid` (clinicId) vem da URL (`?cid=`); **sem `cid` → tela "Clínica não encontrada"** (sem fallback; antes gravava lead de teste na clínica real).
- 4 perguntas com score por resposta; lead com `score`, `answers`, `status='new_lead'`, `origin='web_form'`.
- Grava em `clinics/{cid}/leads` e redireciona ao WhatsApp da clínica com o score.
- Referência: `screens/public/public_evaluation_screen.dart:69-171`.

### RN-56 - Lead "QUENTE" (tela removida)
- A heurística vivia no dashboard `Novos Leads` (removido do menu com `mock_data_service`). Captação via `/avaliacao` (RN-55) continua gravando em `clinics/{cid}/leads`.

### RN-57 - Anamnese/confirmação pública
- `anamnesis/{patientId}`: `get` público (prefill do html) + escrita pública **restrita por allowlist de 14 campos** do formulário; staff auth tem acesso total. Update de status para `'Confirmado'` em `appointments` permitido sem auth (link WhatsApp; regra já mínima via `affectedKeys` — exigir login quebraria o fluxo, decisão mantida).
- Referência: `firestore.rules`.

---

## 12. Regras de Segurança Firestore

### RN-58 - Regras principais (`firestore.rules`)
- `isOwner()`: `users/{uid}.role == 'owner'`.
- `hasClinicAccess(clinicId)`: `clinicId in users/{uid}.allowedClinics`.
- `patients/appointments/financial/treatments/treatment_plans/budgets/clinical_records/psychology_schedules`: auth + (owner **ou** acesso à clínica) — blocos amplos redundantes removidos.
- `expenses`/`lab_orders`: blocos próprios escopados por `clinicId` (todas as leituras do app filtram; creates gravam `clinicId`).
- `settings/*`: leitura auth, escrita owner; `settings/integrations/**`: SÓ owner.
- Exceções públicas: `/anamnesis` (`get` público + escrita por allowlist), `/appointments` update de status para `'Confirmado'` (WhatsApp).
- Mantidos amplos de propósito: `procedures` (global), `inventory`/`suppliers` (leitores legados), `plans`, `anticipations`, `news`.
- Referência: `firestore.rules`, `AGENTS.md`.

---

## 13. Integração WhatsApp

### RN-59 - Normalização de telefone
- Remove não-dígitos; exige **≥10 dígitos**; prefixa DDI `55` se ausente.
- Referência: `services/whatsapp_helper.dart:22-39`.

### RN-60 - Mensagens rotativas
- 3 templates de lembrete de cobrança, escolhidos aleatoriamente (anti-spam).
- Referência: `whatsapp_helper.dart:7-20`.

### RN-61 - Confirmação humana de envio
- Ao voltar do WhatsApp (`AppLifecycleState.resumed`), pergunta "Você enviou?" → SIM marca como cobrado.
- Referência: `screens/financial/collections_screen.dart:37-121`.

---

## 14. Documentação de Arquivos

### RN-62 - Upload/exclusão de documentos
- Upload para **Cloudinary** (`https://api.cloudinary.com/v1_1/dbbh601ay/auto/upload`, `resource_type: auto`, preset unsigned `dbbh601ay`).
- Metadados em `patients/{id}/docs`: `fileType` derivado da extensão (image/document), categoria, título, uploader, `publicId`/`resourceType`.
- Exclusão apaga **só os metadados** (plano Spark, sem Functions → sem destroy remoto; binários órfãos com limpeza manual pelo painel). Cascata: deletes em blocos de 450 + `purgePatientFiles` (só log) **após** o commit OK.
- Referência: `services/document_service.dart`, `patient_docs_tab.dart:348-372`.

---

## 15. Modo Atendimento e Portal

### RN-63 - Modo Atendimento (cobrança nova ou baixa)
- "Meu dia": só hoje, profissional vê só `dentistId == uid`, sem Bloqueado/Cancelado; recepção vê todos + nome do profissional.
- Ficha em 3 blocos: evolução (modelos + texto → `clinical_records` + appointment `Finalizado`), cobrança (nova ou baixa de em-aberto via `processPayment`), próxima sessão (`Agendando`→`Aguardando Confirmação` + `wa.me` padrão).
- Referência: `screens/care/`, `services/care_day.dart` (testado).

### RN-64 - Espelhos do portal
- `portal/{token}`: próximas 3 sessões + top-3 atrasos + `debtsTotal`/`debtsCount` + Pix + `propostasRecusadas` + `clinicId`; `portal_slots/{clinicId}`: livres 14 dias por dentista (`arrayUnion/Remove`).
- `syncPortalMirror()` em todos os pontos de escrita (best-effort, nunca quebra); janela varrida no login (owner/recepção); backfills em `migrate/`; grade configurável (`gradeConfig`, rebuild automático ao salvar).
- Economia de cota: sync por deltas (`upsertSession/removeSession/upsertDebt`: 2 leituras + 1 escrita, sem scans); rebuild completo só na criação, revogação e backfill manual; slots sem varredura no login (botão Reconstruir no Gestão).
- Referência: `services/portal_mirror.dart` (testado), `web/portal.html`.

### RN-65 - Caixa de pendências
- Selo "Decidir remarcação" na agenda + card no Meu dia: aprovar (revalida `getBusySlots`, confirma, sincroniza) ou recusar via WhatsApp (some da lista do paciente, livre pros demais).
- "Avisei que paguei" por débito → selo azul nas Cobranças com dispensar; baixa no fluxo normal.
- Sino no menu: contador laranja em Agenda/Atendimento (remarcar) e Cobranças (avisos); profissional vê só os seus (`pending_counts.dart`, streams compartilhados).
- Referência: `services/remarcacao_service.dart`, `screens/care/remarcar_dialog.dart`.

### RN-66 - Pix da clínica e token do paciente
- `pixKey` em `clinics/{id}`, editável só pelo owner em Gestão → Configurações; exibido no portal.
- Token de 32 chars gerado no cadastro (espelho inicial imediato), copiável e revogável na aba Cadastro; excluir paciente apaga o espelho (cascata).
- Referência: `settings_tab.dart` (`_pixCard`), `patient_details_tab.dart`, `patient_service.dart`.

### RN-67 - Portal: regras de exibição
- Botões só em sessão futura pendente (`Agendado`/`Aguardando Confirmação` como conceito; `Confirmado` só remarca; finais sem ação).
- Débitos: só `dueDate < hoje` não-quitados; "+ mais N" só com espelho novo; `statusSessao` em mapa por sessão (confirmar uma não apaga outra).

### RN-68 - Cota e queries limitadas (Spark 50 mil/dia)
- DRE/Livro Caixa: união de queries mensais por campo de data (exato, dedupe por id) em vez da collection inteira; agenda por semana/mês em cache; kanban filtra `clinicId`.
- Índices compostos em `firestore.indexes.json` (49); deploy separado de rules e indexes.

### RN-69 - Consistência visual e helpers
- Cores só via `AppColors` (+ `StatusChip`); moeda `formatBRL`, datas `formatDate*`, avisos `toast` — tudo em `utils/display.dart` com teste; sem `grey[]`/`DateFormat` soltos nas telas.

---

## 16. Plataforma, Pix e LGPD

### RN-70 - Pix BR Code grátis (sem PSP)
- Gerador local EMV/Bacen (`pixBrCode`: chave + valor + txid + CRC16-CCITT-FALSE, testado com vetor `29B1`); QR + copiar por débito no portal (port JS validado com o mesmo vetor).
- Dinâmico com baixa automática: fora (exige PSP pago). Confirmação segue manual ("Avisei que paguei").
- Referência: `services/pix_brcode.dart`, `web/portal.html`.

### RN-71 - Aceite LGPD do portal
- Checkbox no cadastro (default desmarcado): sem aceite, sem token; sync não autocria com recusa explícita (legados sem campo mantêm autocura); gerar na aba Cadastro registra aceite novo.
- Referência: `create_patient_screen.dart`, `patient_details_tab.dart`, `portal_mirror.dart`.

### RN-72 - Master, Assinatura e landing
- Master só `superadmin` (Owners/Débitos/Trials, gerar mensalidade `40+15×(n−1)`, novo owner+trial, bloqueio manual); trava login em trial expirado OU bloqueio.
- Assinatura fora do app (`assinatura.html`, mesmo login): plano + débitos com Pix e aviso.
- Landing em `/` (Tailwind, logo `logo.png`, preço real, FAQ, form→WhatsApp); `deploy.bat` leva `logo/portal/assinatura` + landing vira `index.html`.
- Referência: `screens/master/master_screen.dart`, `web/assinatura.html`, `web/landing.html`.

---

## Apêndice A - Índice de referências rápidas

| Regra | Arquivo principal |
|-------|-------------------|
| RN-01..06 | `services/session_manager.dart`, `main_web_dashboard.dart` |
| RN-07..17 | `agenda_manager_screen.dart`, `agenda_form_screen.dart`, `appointment_service.dart` |
| RN-18..21 | `create_patient_screen.dart`, `patient_service.dart`, `patient_model.dart` |
| RN-22..23 | `anamnesis_tab.dart`, `clinical_record_screen.dart` |
| RN-24..25 | `odontogram_screen.dart` |
| RN-26..29 | `budgets_tab.dart`, `budget_approval_wizard.dart`, `treatment_service.dart`, `treatments_tab.dart` |
| RN-30..40 | `financial_service.dart`, `payment_service.dart`, `oracle_report_service.dart`, `collections_screen.dart`, `expenses_screen.dart`, `reports_screen.dart` |
| RN-41..45 | `psychology_schedule_form_screen.dart`, `psychology_schedule_model.dart`, `psychology_kanban_board.dart` |
| RN-46..47 | `lab_kanban_board.dart`, `lab_service.dart` |
| RN-48..54 | `clinic_management_screen.dart`, `employee_manager_screen.dart`, `operations/*` |
| RN-55..57 | `public_evaluation_screen.dart`, `firestore.rules` |
| RN-58 | `firestore.rules` |
| RN-59..61 | `whatsapp_helper.dart`, `collections_screen.dart` |
| RN-62 | `document_service.dart` |
| RN-63 | `screens/care/` (Meu dia, ficha, cobrança dupla) |
| RN-64..65 | `services/portal_mirror.dart`, `web/portal.html`, `services/remarcacao_service.dart` |
| RN-66 | `settings_tab.dart`, `patient_details_tab.dart`, cascata |
| RN-67 | `web/portal.html` (regras de exibição) |
| RN-68..69 | queries limitadas, `firestore.indexes.json`, `utils/display.dart` |
| RN-70 | `services/pix_brcode.dart`, `web/portal.html` |
| RN-71 | `create_patient_screen.dart`, `patient_details_tab.dart` |
| RN-72 | `screens/master/`, `web/assinatura.html`, `web/landing.html`, `role_check_screen.dart` |

---

## Apêndice B - Divergências e dívidas conhecidas

| # | Situação | Regra afetada |
|---|----------|---------------|
| 1 | ~~`getAllStream`, `getPatientRiskProfile`, `getByPatientId`, `getPlansStream` sem filtro~~ ✅ corrigido (applyFilter + índices; deploy pendente) | RN-04 |
| 2 | ~~`Cancelado` case-sensitive~~ ✅ corrigido (comparação lowercase nos leitores + teste) | RN-09 |
| 3 | ~~`allowedClinics` hardcoded no registro~~ ✅ corrigido (nasce `[]` + `pending_approval`) | RN-02 |
| 4 | ~~`/avaliacao` com fallback de teste~~ ✅ corrigido (sem cid = erro) | RN-55 |
| 5 | `product_service` legado diverge de `inventory` (`currentQuantity` vs `currentQty`) e não filtra por clínica | RN-04/RN-51 |
| 6 | ~~`treatment_model.dart` documentado mas inexistente~~ ✅ corrigido (removido do AGENTS.md; planos são `Map` crus) | RN-28 |
| 7 | CPF duplicado: query existe mas bloqueio está comentado | RN-18 |
| 8 | ~~Código morto: `_showMonthlyValueDialog`, `_checkForGroupPayment`, `_createNewProfile`, `_buildMinimalistCard`, `_getInitials`, `_isLoadingData`, `receivePayment`, `app_constants.dart`, rules `plans/anticipations`~~ ✅ removido (analyzer) | — |
| 9 | Registro de funcionário pode deslogar o admin (FirebaseApp temporário) | RN-49 |
| 10 | ~~Rules amplas (`financial`, `expenses`, `lab_orders`, `treatments`, `treatment_plans`) liberavam qualquer autenticado~~ ✅ corrigido (redundância removida / blocos escopados; `procedures`/`inventory`/`suppliers` mantidos amplos de propósito) | RN-58 |
| 11 | ~~`patientTabCount` divergia das abas renderizadas (psico 7 vs 6, default 8 vs 9)~~ ✅ corrigido (6/9 + comentário no código) | RN-05 |
| 12 | ~~Segredo Cloudinary lido no client~~ ✅ mitigado no Spark (signing removido do app; sem destroy remoto — só metadados; `settings/integrations` só owner p/ futuro Blaze) | RN-62 |
| 13 | ~~Cascata purgava remoto antes do commit~~ ✅ corrigido (blocos de 450 + purge após commit) | RN-20 |
