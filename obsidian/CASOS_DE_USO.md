---
title: Casos de Uso
tags:
  - nexosaude
  - casos-de-uso
name: casos-de-uso
description: Catálogo UC com atores e referências.
---

# OdontoControle - Casos de Uso do Sistema

Catálogo completo de casos de uso levantados pelo exame do código-fonte. Cada caso lista ator, pré-condições, fluxo principal, alternativas/exceções e referência `arquivo:linha` (caminho relativo a `lib/`).

---

## Atores do Sistema

| Ator | Descrição |
|------|-----------|
| **Owner** | Proprietário/administrador. Vê todas as clínicas via seletor. Menus Clínicas e Funcionários. |
| **Recepcionista** | Agenda, pacientes, cobranças, gestão. Restrito a `allowedClinics`. |
| **Dentista / Psicólogo** | Atendimento clínico, prontuário, odontograma, evolução, kanban terapêutico. |
| **Paciente (externo)** | Sem login; via link público (WhatsApp / Web) responde anamnese, confirma presença, avaliação. |
| **Sistema** | Regras de domínio, batches Firestore, geração automática de registros. |

---

## Módulo 1 - Autenticação e Sessão

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-01 | **Login de usuário** | Usuário | `signInWithEmailAndPassword`; após login chama `_initializeSession` que carrega o doc `users/{uid}` e inicializa o SessionManager (clínica, tipo, role). Enter no campo senha submete (`onSubmitted`); trava anti-duplo-submit. Alternativa: **Entrar com Google** (popup na Web, conta do aparelho no mobile; estreante ganha doc pendente). "Esqueci a senha?" grava pedido em `password_reset_requests` (sem e-mail; responsavel gera temporaria com `reset-senha.bat`). | `screens/auth/login_screen.dart:52-83` |
| UC-02 | **Registrar novo usuário** | Usuário | `createUserWithEmailAndPassword` + grava `users/{uid}` com `role` selecionada (dentista/recepção), `allowedClinics: []` e `status='pending_approval'` (owner libera em Funcionários). Auto-cadastro permitido pela rule (só próprio doc, sem clínica, sem owner). | `login_screen.dart` |
| UC-03 | **Verificar role e clínica no app start** | Sistema | `RoleCheckScreen` lê `users/{uid}`, resolve `allowedClinics` (ou clínica do owner), carrega dados da clínica e chama `SessionManager().setUser(...)`. Menos dados → logout com mensagem. | `screens/auth/role_check_screen.dart:20-76` |
| UC-04 | **Trocar de clínica ativa (owner)** | Owner | Seletor de clínicas no menu busca `clinics where ownerId`; ao trocar, `SessionManager().setClinic(id, name, type)` e snapshots recomeçam filtrando pela nova clínica. Tipo da clínica altera menu (psicologia). | `screens/dashboard/main_web_dashboard.dart:102-199` |
| UC-05 | **Logout** | Qualquer usuário | `SessionManager().clear()` + `signOut` + volta para `AuthWrapper`. | `main_web_dashboard.dart:91-100` |
| UC-06 | **Isolamento multitenant via filtro** | Sistema | `SessionManager().applyFilter(query)`: owner com 'ALL'/null → sem filtro; staff → `clinicId == currentClinicId`; sem clínica → `'waiting_session_init'` (vazio). | `services/session_manager.dart:48-59` |

---

## Módulo 2 - Agenda

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-07 | **Visualizar grade semanal** | Todos | Stream de `appointments` no intervalo da semana com mapa por slot de 30 min. Dentista vê só os seus; recep/owner filtram por dentista. Eventos >30min ocupam várias células. | `screens/agenda/agenda_manager_screen.dart:929-991` |
| UC-08 | **Navegar entre semanas** | Todos | Botões ‹/› ajustam ±7 dias em `_currentWeekStart`. Janela mensal em cache (`MonthAgendaCache`: anterior/atual/proximo; semana em cache = zero leitura). | `agenda_manager_screen.dart:93-95,917-922` |
| UC-09 | **Novo agendamento via célula vazia** | Recep/Owner/Dentista | Toque em célula chama `AgendaCellFactory.openForm` (sem `if clinicType` espalhado): psicologia abre `PsychologyScheduleFormScreen` com data/dia/hora travados; dental abre `AgendaFormScreen` pré-preenchido. | `screens/agenda/agenda_cell_factory.dart`; `agenda_manager_screen.dart` |
| UC-10 | **Verificar/editar agendamento (menu contextual)** | Todos | Toque numa célula abre bottom sheet: abre paciente, edita, finaliza, cancela, envia WhatsApp, encaixe, desbloqueia — conforme o status. Exibe alerta de risco de no-show do paciente (cores). | `agenda_manager_screen.dart:413-616` |
| UC-11 | **Confirmar presença manualmente** | Recep/Owner/Dentista | Update `status='Confirmado'`. | `agenda_manager_screen.dart:512-526` |
| UC-12 | **Enviar confirmação via WhatsApp** | Recep/Owner | Busca telefone do paciente, valida ≥10 dígitos + DDI 55, monta link público `confirmar.html?id=...` e abre `wa.me`. | `agenda_manager_screen.dart:277-306,546-554` |
| UC-13 | **Cancelar agendamento com motivo/origem** | Todos | Dialog com rádio origem (Paciente/Clínica) + motivo obrigatório → grava metadados e **cria registro clínico** "Cancelamento de Consulta". | `agenda_manager_screen.dart:308-410` |
| UC-14 | **Finalizar atendimento (evolução ou falta)** | Dentista/Owner | Rádio Realizado/Não Compareceu. Dental: seleciona plano ativo + procedimento + evolução obrigatória. **Psicologia: sem dropdown** (vínculo automático ao `planId` do pacote, mantém `procedure` do agendamento). Falta tem checkbox **Apresentou Atestado** → grava `hasMedicalCertificate` + nota no prontuário. | `agenda_manager_screen.dart` (`_showFinishAppointmentDialog`) |
| UC-15 | **Bloquear intervalo (1 doc)** | Recep/Owner | "Bloquear Manhã/Tarde/Dia Todo/intervalo" → 1 doc `status='Bloqueado'` (`date`+duração). Regras: com consulta no meio recusa; sobrepostos fundem; repetido avisa sem escrever. | `agenda_manager_screen.dart` (`_applyBlockInterval`) + `services/block_interval.dart` |
| UC-16 | **Liberar dia (remover bloqueios)** | Recep/Owner | Deleta via batch todos `status='Bloqueado'` do dia (respeitando filtro de dentista). | `agenda_manager_screen.dart:147-196` |
| UC-17 | **Desbloquear horário individual** | Recep/Owner | Deleta o doc do agendamento bloqueado. | `agenda_manager_screen.dart:414-428` |
| UC-18 | **Realizar encaixe (2º paciente no mesmo slot)** | Todos | Só quando há 1 evento no horário; abre formulário pré-preenchido. Máx 2. | `agenda_manager_screen.dart:435-436,580-596` |
| UC-19 | **Criar/editar agendamento (formulário)** | Recep/Owner/Dentista | Autocomplete de paciente (query `searchKey`), cadastro rápido de paciente (máscaras RG/CPF/tel/nascimento), seleção múltipla de horários (define duração 30min × N), verificação de disponibilidade inline (ignora edição atual e Cancelado). | `screens/agenda/agenda_form_screen.dart:106-491` |
| UC-20 | **Verificar slots ocupados (serviço)** | Sistema | `getBusySlots`: query do dia, ignora `excludeId` e `'Cancelado'`, marca slots por duração (ceil). | `services/appointment_service.dart:20-45` |

---

## Módulo 3 - Pacientes

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-21 | **Listar pacientes da clínica** | Todos | Stream por `clinicId` ordenado por `createdAt` desc; cards com avatar/nome/tel/CPF. | `screens/patients/patient_list_screen.dart:99-140` |
| UC-22 | **Buscar paciente (nome/CPF/telefone)** | Todos | Filtro client-side local (lowercase). | `patient_list_screen.dart:62-119` |
| UC-23 | **Cadastrar novo paciente** | Todos | Formulário com máscaras (telefone, CPF, data), validações, verificação de CPF duplicado, grava `searchKey`, `status='Ativo'`, `clinicId`. | `screens/patients/create_patient_screen.dart:67-127` |
| UC-24 | **Excluir paciente em cascata** | Todos | Dialog lista tudo que será removido; `deletePatientCascade`: coleta deletes → commit em blocos de 450 → `purgePatientFiles` (só log no Spark). Exclusão de doc apaga só o Firestore (sem destroy remoto no plano Spark). | `patient_list_screen.dart`; `services/patient_service.dart`; `services/document_service.dart` |
| UC-25 | **Navegar abas do paciente** | Todos | Abas dinâmicas por tipo de clínica (`ClinicCapabilities.patientTabCount`): **dental = 9 abas**, **psicologia = 6** (sem ORÇAMENTOS/ODONTOGRAMA/LABORATÓRIO em psicologia). Cabeçalho com 4 cards: risco, a receber (valor−pago), recebido e custo operacional. | `screens/patients/patient_details_screen.dart` |
| UC-26 | **Editar dados cadastrais** | Todos | Aba CADASTRO: alterna modo edição, atualiza nome/tel/CPF/RG/nascimento/endereço + `searchKey`. | `screens/patients/tabs/patient_details_tab.dart:30-161` |
| UC-27 | **Anamnese (visualizar/salvar)** | Todos | Stream do doc `anamnesis/{patientId}`; formulário com histórico patológico, hábitos, alergias, observações; `set()` completo ao salvar. | `screens/patients/tabs/anamnesis_tab.dart:64-321` |
| UC-28 | **Enviar anamnese ao paciente via WhatsApp** | Todos | Link público `anamnesis.html?id=...` + `wa.me`. | `anamnesis_tab.dart:153-189` |
| UC-29 | **Criar orçamento** | Todos (dental) | Dialog com seleção de procedimento (stream), itens com preço personalizado e total; grava `BudgetModel status='Pendente'`. | `screens/patients/tabs/budgets_tab.dart:28-279` |
| UC-30 | **Aprovar orçamento (wizard mensalidades)** | Todos (dental) | `BudgetApprovalWizard`: se procedimento tem `generatesMonthlyFee`, ativa passos de mensalidade (valor, parcelas, vencimento); depois gera recebíveis (mensalidades + 1 receita/item) e custo automático; `TreatmentService.approveBudgetWithFinancials` grava plano + financeiro + despesas em batch. | `budgets_tab.dart:283-297`; `screens/patients/wizards/budget_approval_wizard.dart:45-318`; `services/treatment_service.dart:33-96` |
| UC-31 | **Visualizar tratamentos e raio-X financeiro** | Todos | Agrupa planos por `planId` + parcelas; calcula recebido/custos lab/repasse/margem/progresso; dialog "Margem: X%". Encerra plano (`status='completed'`). | `screens/patients/tabs/treatments_tab.dart:29-309` |
| UC-32 | **Prontuário (evoluções)** | Dentista/Psicólogo | Novo registro (seleciona plano ativo + procedimento + descrição), editar, excluir. Cria histórico em `clinical_records`. | `screens/patients/tabs/clinical_record_screen.dart:34-259` |
| UC-33 | **Odontograma** | Dentista | `InteractiveViewer` com zoom; marca faces por estado (saudável/cárie/restaurado/coroa/implante/extrair/endodontia) com regras de conflito (implante limpa faces, extração marca dentes ausentes); salva em `patients/{id}/clinical_data/odontogram`. | `screens/patients/tabs/odontogram_screen.dart:26-278` |
| UC-34 | **Documentação: upload (câmera/arquivo)** | Todos | Upload para Cloudinary (multipart, web/mobile), categorização (Exames/Radiografias/Documentos/Contratos/Fotos/Outros), metadados em `patients/{id}/docs`. Visualiza (photo_view ou app externo) e exclui. | `screens/patients/tabs/patient_docs_tab.dart:32-364`; `services/document_service.dart:20-109` |
| UC-35 | **Perfil de risco de no-show** | Sistema | Últimos 20 agendamentos: conta `Missed` **sem atestado** + cancelado pelo paciente → red (≥30% ou ≥3), yellow (≥10%), green. | `services/patient_service.dart` |
| UC-36 | **Card de contexto "IA"** | Sistema | Gera resumo narrativo: última evolução, alertas de saúde (anamnese) e pendências vencidas. Card oculto se nada relevante. | `widgets/patient_smart_context_card.dart:13-170` |
| UC-37 | **Timeline financeira do paciente** | Todos | Merge de receitas e despesas numa timeline única (totais moram no cabeçalho da ficha, não aqui). Filtros em bottom sheet (valor mín/máx, procedimento) + toggle de ordenação (padrão: vencimentos próximos; nulos por último); contador "X de Y". | `screens/patients/tabs/patient_financial_tab.dart` |
| UC-38 | **Receber pagamento (wizard)** | Recep/Owner | Bottom-sheet completo: valor, método (Dinheiro/Pix/Débito/Cartão com faixas da máquina), parcelamento com taxas, repasse profissional (comissão %/R$), custo operacional (fornecedor), opção gerar pedido de lab; grava tudo em batch (pagamento, despesa de comissão/custo, lab_order). Cartão parcelado → título original deletado + `machineProfileId`. | `patient_financial_tab.dart:337-977` |
| UC-39 | **Estornar pagamento** | Recep/Owner | Verifica despesas/lab orders vinculados (aviso laranja), deleta-os e zera dados do pagamento (volta a Pendente). Botão **CORRIGIR E RELANÇAR** reabre o recebimento pré-preenchido. Toque no item abre **menu por estado**: pendente (Receber/Editar/Cancelar), pago (Estornar-Corrigir/Cancelar), cancelado (Recriar com valores editáveis). | `patient_financial_tab.dart:110-201`; `services/financial_service.dart:21-34` |
| UC-40 | **Lembrete de pagamento via WhatsApp** | Recep/Owner | Monta mensagem com valor/vencimento e abre `wa.me`. | `patient_financial_tab.dart:85-107` |

---

## Módulo 4 - Financeiro, Cobranças e Relatórios

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-41 | **Processar pagamento à vista/parcelado (serviço)** | Sistema | À vista (1x, cobre tudo) → update no original com taxas e dados do pagador. Parcelado → update do original com status "(Renegociado/Parcelado)" + cria N lançamentos filhos com ajuste de centavos na 1ª parcela e `dueDate` +30d. | `services/financial_service.dart:37-143` |
| UC-42 | **Fluxo de caixa real (livro-caixa)** | Todos | Combina streams de `financial` + `expenses` por mês em regime de caixa; mostra saldo realizado, saldo acumulado por linha e previsão. | `screens/financial/financial_report_screen.dart:342-494`; `services/oracle_report_service.dart:58-199` |
| UC-43 | **Estornar lançamento (livro-caixa)** | Todos | Long-press em linha paga → reverte receita (volta a Pendente/saldo devedor) ou despesa (volta a pendente). | `financial_report_screen.dart:293-329`; `services/payment_service.dart:104-122` |
| UC-44 | **Exportar relatório fiscal** | Todos | Dialog EXCEL ou PDF. **PDF para o Carnê-Leão**: dados do usuário (nome/CPF/CRO/endereço), tabela A4 por transação com CPF dos pacientes, totais e resultado líquido; compartilha via `Printing.sharePdf`. **ExcelCSV**: download na web via Blob/anchor; desktop salva e abre. | `financial_report_screen.dart:37-290` |
| UC-45 | **Listar cobranças pendentes do mês** | Todos | Query `financial` com `status whereIn ['pendente','pending']`, `type=='income'`. Modo pacotes (`monthlyPeriod`, só psico) ou Por Sessão (`dueDate` no mês, **exclui pacotes** via `billingKind`/`monthlyPeriod`). | `screens/financial/collections_screen.dart` |
| UC-46 | **Enviar cobrança individual via WhatsApp** | Todos | Mensagens rotativas (3 templates anti-spam), normaliza DDI, abre `wa.me`. Retorno do app → dialog "Confirmação" (humano valida). "SIM" → `status='cobrado'`, `lastContactDate`, `contactHistory`. Badge "Já contatado hoje". | `collections_screen.dart`; `widgets/charge_confirm_dialog.dart`; `services/whatsapp_helper.dart` |
| UC-47 | **Contas a pagar (despesas)** | Todos | Listar por mês, cadastrar nova despesa (descrição, valor, categoria, vencimento), baixar pagamento (`markAsPaid`), filtro por status. Cards coloridos: vencido/em breve/aberto/pago. | `screens/financial/expenses_screen.dart:32-298`; `services/expense_service.dart:9-102` |
| UC-48 | **Painel DRE gerencial** | Todos | KPIs: receita realizada, despesas pagas, lucro líquido, margem %, previsão de fechamento. Navegação mensal com debounce. | `screens/reports/reports_screen.dart:186-320` |
| UC-49 | **Simular e processar antecipação de recebíveis** | Todos | Calcula elegíveis (receitas de cartão não canceladas/antecipadas com `dueDate` válido), taxa mensal de `settings/fees` (default 2,29%), resumo bruto/líquido, grava despesa de taxa + marca parcelas `anticipated`. | `reports_screen.dart:328-651` |
| UC-50 | **Criar despesa recorrente (parcelada)** | Sistema | Batch cria N docs com `dueDate` mensal, `installmentNumber i/N`, `recurrenceId`. | `services/expense_service.dart:23-66` |
| UC-51 | **Receber pagamento parcial** | Sistema | `payment_service`: pagamento parcial cria lançamento "(Restante)" pendente; parcelamento "explosão" transforma original em parcela 1 e cria N-1 em D+30; total à vista marca com profissional para comissão. | `services/payment_service.dart:24-98` |

---

## Módulo 5 - Psicologia

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-52 | **Acompanhar contratos de psicologia** | Staff/Owner | Tela de lista removida do menu; contratos ativos se acompanham pela **agenda** (sessões geradas) e pelo **kanban**. Leitura direta de `psychology_schedules` por `clinicId` + `status=='active'` (sem service dedicado). |
| UC-53 | **Criar agenda de psicologia (pacote/avulsa)** | Staff/Owner | Formulário: paciente, tipo, data início, dia da semana, horário, valores, convênio/desconto. Ao salvar, `_generateAppointments` cria: **tratamento** (`treatment_plans`), **financeiro** (pacote = 1/mês com `billingKind`/`monthlyPeriod`, vence dia 10 seguinte; **avulsa = 1 sessão só** na data selecionada, +7 dias) e **appointments** (60min, "Aguardando Confirmação", com `scheduleId/planId/monthlyPeriod`) — tudo em batch. | `screens/psychology/psychology_schedule_form_screen.dart` |
| UC-54 | **Gerar sessões recorrentes até fim do ano** | Sistema | Pacote: `generateSessionDates` itera semanalmente até 31/12. Avulsa: somente a data selecionada. | `models/psychology_schedule_model.dart` |
| UC-55 | **Editar/cancelar agenda de psicologia** | Staff/Owner | Edição no form não regenera sessões. **Cancelar contrato** (botão no modo edição): confirma escopo → futuras não finalizadas viram `Cancelado`, financeiros `pendente/pending` do plano viram `Cancelado`; finalizados/pagos intactos; batch em blocos de 450. | `psychology_schedule_form_screen.dart` (`_confirmCancelSchedule`, `_cancelSchedule`) |
| UC-56 | **Fluxo terapêutico (Kanban PsychoFlow)** | Psicólogo/Recep/Owner | Colunas Prospecto → Acompanhamento → Alta-Manutenção (gravados `lead/active/discharged` em `patients.status`). Drag & drop entre colunas com transições validadas. | `screens/patients/psychology/psychology_kanban_board.dart:29-301` |
| UC-57 | **Iniciar tratamento (Lead → Ativo)** | Psicólogo/Recep | Dialog com checklist obrigatório (Contrato Terapêutico, Anamnese, Dados de Faturamento) → `status='active'`. | `psychology_kanban_board.dart:304-353` |
| UC-58 | **Registrar alta (Ativo → Alta)** | Psicólogo | Dialog pede motivo obrigatório → `status='discharged'`, `discharge_reason/date`. | `psychology_kanban_board.dart:356-392` |
| UC-59 | **Valor efetivo do pacote** | Sistema | `effectiveValue` = valor do pacote (ou sessão) − `thirdPartyDiscount`. | `models/psychology_schedule_model.dart:81-86` |

> **Implementado:** cobrança mensal por pacote com rateio por presença — ver UC-80 e `PSYCHOLOGY_PACKAGES.md`.

---

## Módulo 6 - Gestão (Clínicas, Funcionários, Operações)

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-60 | **Criar clínica/unidade** | Owner | Dialog nome, tipo (odontológica/psicológica/fisioterapêutica/yoga), telefone/endereço; grava `clinics` e adiciona `clinicId` em `allowedClinics` do owner. | `screens/clinics/clinic_management_screen.dart:15-134` |
| UC-61 | **Listar clínicas do owner** | Owner | Stream `clinics where ownerId` em grid com ícone por tipo. | `clinic_management_screen.dart:172-272` |
| UC-62 | **Cadastrar funcionário sem deslogar o admin** | Owner | Cria **FirebaseApp temporário** → `createUserWithEmailAndPassword` → grava `users/{uid}` com role e `allowedClinics:[clinicId]` → destrói app temporário (embora ocorra em outro contexto auth, pode deslogar em algumas versões). Owner escolhe a clínica; staff usa a atual. | `screens/employees/employee_manager_screen.dart:33-209` |
| UC-63 | **Listar funcionários da clínica** | Owner/Gerente/Recep | Stream `users where allowedClinics arrayContains clinic`; badge "Dono". | `employee_manager_screen.dart:248-289` |
| UC-64 | **Buscar profissionais da clínica por tipo** | Sistema | Lê tipo da clínica e filtra `users` por `allowedClinics`: psicologia → psicólogo/owner; odontologia → dentista/owner. | `services/user_service.dart:13-53` |
| UC-65 | **Gestão: módulos operacionais** | Owner/Gerente | Abas PROCEDIMENTOS, ESTOQUE, FORNECEDORES, CARTÕES, CONFIGURAÇÕES (tema + acesso + "Minha conta": troca de senha com re-autenticacao). | `screens/operations/operations_manager_screen.dart` |
| UC-66 | **Estoque (CRUD + alerta de reposição)** | Owner/Gerente/Recep | Lista com `isLowStock` (qtd ≤ mín). Ajuste rápido ±1 via `FieldValue.increment` atômico. | `screens/operations/tabs/inventory_tab.dart:15-168`; `services/inventory_service.dart:10-32` |
| UC-67 | **Procedimentos (CRUD + repasse)** | Owner/Gerente | Dialog com categoria, preço, repasse profissional (%/fixo), switches "Gera Custos" e "Gera Mensalidade". | `screens/operations/tabs/procedures_tab.dart:16-247`; `services/procedure_service.dart:10-32` |
| UC-68 | **Fornecedores (CRUD)** | Owner/Gerente | Categoria (laboratório, dentista parceiro, consumo, manutenção, serviços, impostos), switch "É Dentista da Equipe?" (`isProfessional` → comissão). | `screens/operations/tabs/suppliers_tab.dart:27-179` |
| UC-69 | **Tarifas de cartão (perfis de máquina)** | Owner/Gerente | Perfis em `clinics/{id}/settings/fees/profiles`: taxa débito, crédito à vista, faixas de parcelamento dinâmicas (de/até/taxa) e taxa de antecipação mensal; definir padrão; excluir. | `screens/operations/tabs/card_fees_tab.dart:60-529` |

---

## Módulo 7 - Laboratório

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-70 | **Kanban de ordens de laboratório** | Dentista/Owner | Stream por `clinicId` com filtros de busca/laboratório/dentista; colunas Solicitar → Enviado (`sentDate`) → Devolução (`returnDate`) → Entregue (`deliveredDate`) com arrastar-soltar. | `screens/lab/clinic_lab_screen.dart:56-166`; `widgets/lab_kanban_board.dart:54-120` |
| UC-71 | **Criar pedido manual (na aba do paciente)** | Dentista | Vincula tratamento opcional + solicitante + descrição; `status='pending_send'`. | `screens/patients/tabs/patient_lab_tab.dart:26-143` |
| UC-72 | **Excluir pedido / adicionar interação / ver histórico** | Dentista | Deletar com confirmação; interações (Problema/Atraso) via `arrayUnion` em pedidos enviados. | `lab_kanban_board.dart:26-148`; `services/lab_service.dart:11-47` |

---

## Módulo 8 - Notícias

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-73 | **Ver notícias de ortodontia** | Todos | `FutureBuilder` lista artigos científicos (título, resumo, data); toque abre o link externo; botão atualizar. | `screens/news/ortho_news_screen.dart:13-114` |

(UC-74/75/76 — dashboard de leads, contato e mock — **removidos** com a tela `Novos Leads`. Captação pública via `/avaliacao` continua em UC-79.)

---

## Módulo 9 - Fluxos Públicos (Sem Login)

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-77 | **Confirmação de consulta via link público** | Paciente | Link `confirmar.html?id=<appt>` permite atualizar status para "Confirmado" (regra específica no Firestore). | `firestore.rules`; `agenda_manager_screen.dart:546-554` |
| UC-78 | **Anamnese pública** | Paciente | Write público em `anamnesis/{patientId}` via WhatsApp link. | `firestore.rules`; `anamnesis_tab.dart:170-184` |
| UC-79 | **Avaliação digital de leads (rota /avaliacao)** | Paciente | Questionário com score por resposta; grava em `clinics/{cid}/leads` e redireciona ao WhatsApp da clínica. Sem `?cid=` → "Clínica não encontrada" (sem fallback). | `screens/public/public_evaluation_screen.dart:69-97` |

---

## Módulo 10 - Pacotes por presença e cobrança (novo)

| # | Caso de Uso | Ator | Resumo | Ref. |
|---|-------------|------|--------|------|
| UC-80 | **Billing mensal rateado por presença** | Sistema | `PackageBilling.compute` (puro): teto = pacote − desconto; divisor = previstas; cobrável = Realizado + falta sem atestado; parcial se incompleto. Card mostra `x/y • R$`. Congela no `paid`. | `services/package_billing.dart` |
| UC-81 | **Falta com atestado** | Recep/Owner | Checkbox no finalizar; grava `hasMedicalCertificate`; abate do pacote e isenta o risco. Docs antigos (sem campo) contam como sem atestado. | `agenda_manager_screen.dart`; `patient_service.dart` |
| UC-82 | **Skeleton do cálculo no card** | Todos | `BillingSkeleton` (shimmer, sem pulo de layout) enquanto calcula; timeout 5s → valor cheio + "Cálculo indisponível". | `screens/financial/widgets/billing_skeleton.dart` |
| UC-83 | **Capabilities por tipo de clínica** | Sistema | `ClinicCapabilities` centraliza guards (tabs, menu, papéis, billing mensal). Proibido comparar `clinicType` solto. | `services/clinic_capabilities.dart` |
| UC-84 | **Dashboard de KPIs (item 1)** | Todos | 4 cards (A Receber mês, Inadimplência, Agendamentos hoje, Aniversariantes) + próximos vencimentos + aniversariantes; `birthDate` String com parse defensivo. **Hoje conta só `status='Confirmado'`.** | `screens/dashboard/kpi_dashboard_screen.dart` |
| UC-85 | **Modo Atendimento (item 12)** | Dentista/Psicologo/Owner | "Meu dia" (só hoje; profissional vê o próprio) + ficha em 3 blocos: evolução rápida com modelos, cobrança (Pix ou pendente), próxima sessão + WhatsApp. Helpers puros em `services/care_day.dart` (testado). | `screens/care/care_day_screen.dart` + `screens/care/care_visit_screen.dart` |
| UC-86 | **Portal do paciente (HTML público)** | Paciente (link) | `web/portal.html?t=TOKEN`: sessões (confirmar/remarcar com slots livres de 14 dias), débitos + Pix + "avisei que paguei". Espelhos `portal/{token}` + `portal_slots/{clinicId}` (rules A4, allowlist). Sync via `PortalMirrorSync` nos pontos de escrita. | `web/portal.html` + `services/portal_mirror.dart` |
| UC-87 | **Caixa de pendências (remarcar + aviso pago)** | Recep/Dentista | Selo "Decidir remarcação" na agenda + tile no Meu dia: aprovar (revalida choque, confirma, sincroniza) ou recusar via WhatsApp (some da lista do paciente). Selo "Avisei que paguei" nas Cobranças com dispensar; baixa segue no fluxo normal. | `screens/care/remarcar_dialog.dart` + `services/remarcacao_service.dart` |
| UC-88 | **Cobrança dupla no atendimento** | Dentista/Psicologo | Alternador Nova/Em aberto: nova (pendente ou recebido) ou baixa de lançamento existente via `processPayment`. | `screens/care/care_visit_screen.dart` |
| UC-89 | **Link do portal no Cadastro** | Recep/Owner | Gerar (espelho imediato), copiar e revogar token na aba Cadastro; excluir paciente apaga o espelho. | `patient_details_tab.dart` + cascata |
| UC-90 | **Pix da clínica** | Owner | Salvar `pixKey` em Gestão → Configurações (só owner escreve); exibido no portal por débito. | `settings_tab.dart` |
| UC-91 | **Portal: atrasos e painel refeito** | Paciente (link) | Só `dueDate < hoje` (top 3 + totais); toggle Pix por débito + "Avisei que paguei" individual; painel dias/horários filtrado pelo profissional. | `web/portal.html` |
| UC-92 | **Sino de pendências no menu** | Recep/Dentista | Contador laranja em Agenda/Atendimento (remarcar) e Cobranças (avisos); profissional vê só os seus. | `main_web_dashboard.dart` + `services/pending_counts.dart` |
| UC-93 | **Grade de horários da clínica** | Owner | Salvar início/fim/slot em Gestão → Configurações; reconstrói os slots do portal na hora. | `settings_tab.dart` + `portal_mirror.dart` |
| UC-94 | **Master da plataforma** | Superadmin | Abas Owners (bloquear/liberar, gerar mensalidade, novo owner+trial), Débitos (baixa/dispensa) e Trials. | `screens/master/master_screen.dart` + `web/master.html` |
| UC-95 | **Assinatura do owner (página pública)** | Owner | Mesmo login em `assinatura.html`: resumo do plano + débitos com Pix e "avisei que paguei" (fora do app). | `web/assinatura.html` |
| UC-96 | **Landing + trava de assinatura** | Visitante/Usuário | `/` abre a landing (sem redirect); trial expirado ou bloqueio manual barra o login com tela explicativa. | `web/landing.html` + `role_check_screen.dart` |
| UC-99 | **Trial com porteira (autoprovisionamento aprovado)** | Visitante | Cadastro em `assinatura.html` cria Auth + owner pendente + `trial_requests`; Master aprova (cria clínica + trial 7d) ou recusa; relógio anda após aprovação. | `web/assinatura.html` + `web/master.html` + rules A1b |
| UC-97 | **Pix BR Code grátis** | Paciente (link) | QR + copiar por débito gerados localmente (padrão Bacen, sem PSP); confirmação segue manual. | `services/pix_brcode.dart` + `web/portal.html` |
| UC-98 | **Aceite LGPD no cadastro** | Recep/Owner | Checkbox default desmarcado; sem aceite, sem token; gerar depois registra aceite. | `create_patient_screen.dart` |
| UC-100 | **Menu por controle de acesso** | Todos | Itens/detalhe por `menuAccess` + defaults por papel; dentista liberável em Gestão; Master só superadmin. | `main_web_dashboard.dart` + `menu_access.dart` |
| UC-101 | **Gestão por abas** | Owner/(liberados) | Abas e seções Pix/Grade/Acesso/Dados filtradas por sub-chaves; editor com grupo dedicado. | `operations_manager_screen.dart` + `settings_tab.dart` |
| UC-102 | **Trocar de clínica** | Owner/multi-clínica | Seletor ou Gerenciar (troca real de contexto); vínculo editado em Funcionários. | `main_web_dashboard.dart` + `clinic_management_screen.dart` |
| UC-103 | **WhatsApp da clínica** | Owner/(liberados) | Número canônico em Config; Avaliação abre o chat da unidade. | `settings_tab.dart` + `public_evaluation_screen.dart` |
| UC-104 | **Atendimento em modal** | Dentista/Recep | Cards translúcidos; ficha (evolução/cobrança/próxima) em modal 92%, sem nova tela. | `care_day_screen.dart` + `care_visit_screen.dart` |
| UC-105 | **Alterar senha de funcionário** | Owner | Sheet no tile cria pedido; `.bat` efetiva; temporária em Pedidos com copiar/dispensar. | `employee_manager_screen.dart` + `migrate/reset-senha.bat` |

---

## Observações Transversais

1. **Isolamento multitenant:** services usam `SessionManager().applyFilter()` (budget, clinical_record, oracle, inventory, supplier, procedure, patient risk/list, financial por paciente, treatment plans, lab por paciente, smart-card, abas Pagamentos). **Restam sem filtro**: `product_service` (legado), `procedures` (global por desenho), leituras de gestão amplas nas rules (decisão documentada).
2. **Soft delete vs exclusão física:** agenda psicologia e schedules usam `status='cancelled'`; inventário/fornecedores/procedimentos deletam o doc; paciente usa cascata de delete.
3. **Duplicação de lógica:** verificação de disponibilidade existe duplicada no service (`getBusySlots`) e inline nos dois formulários de agenda (padrão duplicação em 3 lugares).
4. **Código morto identificado:** `budgets_tab._showMonthlyValueDialog` (:299-322) e `patient_financial_tab._checkForGroupPayment` (:979-1013) nunca são chamados.
5. **Roles nos menus:** Financeiro/Relatórios/Cobranças/Notícias/Laboratório não têm guard de role no código; a efetiva separação é feita pelas regras do Firestore e pelo seletor de clínicas (owner).
6. **Ciclo de status do agendamento:** `Aguardando Confirmação` → `Confirmado` → `Finalizado` (+`attendanceStatus`) ou `Cancelado` (com metadados) / `Bloqueado` (sintético, deletável).
7. ~~`treatment_model.dart` listado no AGENTS.md mas inexistente~~ ✅ corrigido (removido do AGENTS.md; planos são `Map`s crus de `treatment_plans`).
8. ~~`patientTabCount` divergia das abas (psico 7 vs 6, default 8 vs 9)~~ ✅ corrigido em `clinic_capabilities.dart` (6/9).

---

## Resumo por Módulo

| Módulo | Casos |
|--------|------:|
| Autenticação/Sessão | 6 (UC-01..06) |
| Agenda | 14 (UC-07..20) |
| Pacientes | 20 (UC-21..40) |
| Financeiro/Relatórios | 11 (UC-41..51) |
| Psicologia | 8 (UC-52..59) |
| Gestão | 10 (UC-60..69) |
| Laboratório | 3 (UC-70..72) |
| Notícias | 1 (UC-73) |
| Fluxos Públicos | 3 (UC-77..79) |
| Pacotes/presença (novo) | 4 (UC-80..83) |
| Dashboard KPI | 1 (UC-84) |
| **Total** | **81 casos de uso** |
## Ver tamb�m

- [[PRD]] � produto e riscos
- [[Requisitos]] � RNs por tr�s dos UCs
- [[atendimento]] � mapa do Modo Atendimento
