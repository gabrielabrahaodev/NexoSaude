---
title: Diagramas de Sequência
tags:
  - nexosaude
  - diagramas
name: diagramas-sequencia
description: Fluxos principais em sequência.
type: spec
status: stable
updated: 2026-09-30
---

# OdontoControle - Diagramas de Sequência

Diagramas das principais funcionalidades do sistema. Renderizados em Mermaid (GitHub / VS Code com extensão Mermaid).

---

## 1. Autenticação e Inicialização da Sessão

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant M as main.dart (AuthWrapper)
    participant A as FirebaseAuth
    participant L as LoginScreen
    participant R as RoleCheckScreen
    participant F as Firestore (users/clinics)
    participant S as SessionManager

    M->>A: authStateChanges() (stream)
    A-->>M: usuário logado? 

    alt Não logado
        M-->>U: LoginScreen
        U->>L: email + senha
        L->>A: signInWithEmailAndPassword()
        A-->>L: User (uid)
    end

    M-->>R: usuário logado
    R->>A: currentUser
    R->>F: users/{uid}.get()
    F-->>R: { role, allowedClinics[] }

    alt owner sem allowedClinics
        R->>F: clinics.where('ownerId', == uid).limit(1)
        F-->>R: primeira clínica
    end

    R->>F: clinics/{clinicId}.get()
    F-->>R: { name, type }
    R->>S: setUser(id, role, clinicId, clinicName, clinicType)
    S-->>S: notifyListeners()
    R->>R: pushReplacement → MainWebDashboard
```

---

## 2. Troca de Clínica (Multi-tenant / Owner)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário (owner)
    participant D as MainWebDashboard
    participant S as SessionManager
    participant T as Tela Ativa (ex: Agenda)
    participant F as Firestore

    U->>D: seleciona clínica no seletor
    D->>S: setClinic(id, name, type)
    S-->>S: notifyListeners()
    S-->>D: rebuild do dashboard
    D->>T: reconstrói com ValueKey(_currentClinicId)
    T->>F: query filtrada por clinicId
    F-->>T: dados da clínica atual

    Note over S,T: applyFilter():<br/>owner com 'ALL'/null → sem filtro<br/>staff → clinicId == clínica atual<br/>sem clinicId → 'waiting_session_init' (vazio)
```

---

## 3. Agenda - Criar Consulta

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant A as AgendaManagerScreen
    participant Fm as AgendaFormScreen
    participant AS as AppointmentService
    participant S as SessionManager
    participant F as Firestore

    U->>A: clica em "Nova Consulta"
    A->>Fm: abre formulário
    Fm->>S: currentClinicId
    Fm->>AS: getBusySlots(clinicId, data)
    AS->>F: appointments (clinicId + range de data)
    F-->>AS: slots ocupados
    AS-->>Fm: lista de horários ocupados (exclui Cancelado)

    U->>Fm: preenche paciente/dentista/procedimento/horário
    Fm->>AS: add(AppointmentModel)
    AS->>F: appointments.add(toMap())
    F-->>Fm: sucesso
    Fm-->>U: SnackBar "Consulta agendada"
    A-->>A: stream snapshots() atualiza agenda
```

---

## 4. Agenda - Confirmação via WhatsApp

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    actor P as Paciente
    participant A as AgendaManagerScreen
    participant W as WhatsAppHelper
    participant F as Firestore (appointments)

    U->>A: clica "Enviar confirmação" no card
    A->>W: abre wa.me link (telefone + mensagem)
    W-->>P: link do WhatsApp

    alt Paciente confirma
        P-->>U: responde no WhatsApp
        U->>A: marca como "Confirmado"
        A->>F: appointments/{id}.update(status = 'Confirmado')
        Note over F: Regra Firestore permite update<br/>de status para 'Confirmado'
    end
```

---

## 5. Cadastro de Paciente + Perfil de Risco

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant C as CreatePatientScreen
    participant PS as PatientService
    participant S as SessionManager
    participant F as Firestore (patients/appointments)

    U->>C: preenche dados do paciente
    C->>S: currentClinicId
    C->>PS: add(PatientModel)
    PS->>F: patients.add(toMap()) (defensive parsing)
    F-->>C: sucesso

    Note over PS: getPatientRiskProfile(patientId)
    PS->>F: appointments.where(patientId).orderBy(date, desc).limit(20)
    F-->>PS: últimas 20 consultas
    Note over PS: conta Missed / Cancelado pelo Paciente<br/>>=30% ou >=3 → red<br/>>=10% → yellow<br/>senão → green
    PS-->>U: nível de risco exibido no card
```

---

## 6. Exclusão em Cascata do Paciente

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant PL as PatientListScreen
    participant PS as PatientService
    participant F as Firestore
    participant B as Batch

    U->>PL: confirma exclusão do paciente
    PL->>PS: deletePatientCascade(patientId, clinicId)
    PS->>PS: purgePatientFiles (destroy no Cloudinary via publicId;<br/>sem credenciais em settings/integrations, só Firestore)
    PS->>F: query por coleção (clinicId + patientId)
    F-->>PS: docs encontrados

    loop Para cada coleção
        Note over PS,F: appointments, budgets, treatments,<br/>treatment_plans, financial,<br/>clinical_records, lab_orders,<br/>psychology_schedules, subcoleções
        PS->>B: batch.delete(reference)
    end

    PS->>B: batch.delete(patientRef)
    PS->>F: batch.commit()
    F-->>PS: sucesso
    PS-->>U: "Paciente excluído em cascata (N docs)"
```

---

## 7. Financeiro - Processar Pagamento

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant T as PatientFinancialTab / CollectionsScreen
    participant FS as FinancialService
    participant B as Batch
    participant F as Firestore (financial)

    U->>T: inicia pagamento (valor, método, parcelas)
    T->>FS: processPayment(original, payValue, method, installments, ...)

    alt À vista (cobre tudo, 1 parcela)
        FS->>F: update original (isPaid, status 'Pago', method, taxas)
    else Parcelado / Renegociado
        FS->>F: update original (status 'Pago (Renegociado/Parcelado)')
        loop Para cada parcela i
            Note over FS,F: ajuste de centavos (bruto e líquido)<br/>na 1ª parcela
            FS->>F: set novo doc (dueDate +30d, installmentNumber 'i/N', taxas)
        end
    end

    FS->>F: batch.commit()
    F-->>T: streams snapshots() atualizam telas
```

---

## 8. Financeiro - Estorno de Pagamento

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant T as PatientFinancialTab
    participant FS as FinancialService
    participant F as Firestore (financial)

    U->>T: clica "Estornar" no lançamento
    T->>FS: voidPayment(id)
    FS->>F: update doc (status 'Pendente', isPaid false,<br/>zerar paidAmount/taxas/líquido)
    F-->>T: stream atualiza status do lançamento
```

---

## 9. Agenda Psicologia - Gerar Sessões (Pacote / Avulso)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant P as PsychologyScheduleFormScreen
    participant S as SessionManager
    participant F as Firestore
    participant B as Batch

    U->>P: preenche paciente, tipo (pacote/avulsa), dia/hora, valores
    P->>S: currentClinicId
    P->>F: psychology_schedules.add(schedule)
    F-->>P: scheduleId

    P->>P: pacote = generateSessionDates(até 31/12 do ano);<br/>avulsa = 1 sessão na data selecionada
    P->>F: cria treatment_plans (items = sessões, planId)

    alt Pacote
        Note over P,F: 1 doc financeiro por mês<br/>(monthlyPeriod, billingKind, vence dia 10 seguinte)
        P->>B: financial.set(1 doc/mês, installmentNumber 'Jan/2025 1/5', planId)
    else Sessão Avulsa
        P->>B: financial.set(1 doc, dueDate = sessão + 7 dias,<br/>installmentNumber '1/1', billingKind 'session')
    end

    loop Para cada sessão
        P->>B: appointments.set(AppointmentModel,<br/>status 'Aguardando Confirmação', 60min,<br/>scheduleId/planId/monthlyPeriod)
    end

    P->>F: batch.commit()
    P-->>U: "Agendamento salvo e sessões geradas!"
```

---

## 10. Orçamento / Fluxo de Aprovação (gera financeiro direto)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant D as PatientDetailsScreen (ORÇAMENTOS)
    participant BS as BudgetService
    participant W as BudgetApprovalWizard
    participant TS as TreatmentService
    participant F as Firestore (budgets/treatment_plans/financial)

    U->>D: cria orçamento (items, valores)
    U->>BS: budgets.add(items[], status='Pendente')
    BS->>F: budgets.add()
    F-->>U: orçamento criado

    U->>D: clica aprovar no orçamento
    D->>W: BudgetApprovalWizard (se item tem generatesMonthlyFee,<br/>passos de mensalidade: valor, parcelas, vencimento)
    W->>TS: approveBudgetWithFinancials
    TS->>F: batch: treatment_plans (plano active) +<br/>financial (N mensalidades i/N + 1 receita/item) +<br/>expenses (Custo Inicial, se houver custo)
    F-->>D: tabs ORÇAMENTOS/TRATAMENTOS/PAGAMENTOS atualizam
```

---

## 11. Laboratório - Kanban de Ordens

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant K as ClinicLabScreen / LabKanbanBoard
    participant LS as LabService
    participant F as Firestore (lab_orders)

    U->>K: visualiza colunas (Solicitado / Em produção / Pronto / Entregue)
    K->>LS: getByClinicId(clinicId) stream
    LS->>F: lab_orders.where(clinicId)
    F-->>K: atualização em tempo real

    U->>K: arrasta ordem para outra coluna
    K->>LS: update(status)
    LS->>F: lab_orders/{id}.update(status)
    F-->>K: kanban reordena
```

---

## 12. Anamnese Pública (WhatsApp Link)

```mermaid
sequenceDiagram
    autonumber
    actor P as Paciente (sem login)
    participant H as anamnese.html (link público ?id=patientId)
    participant F as Firestore (anamnesis)

    P->>H: abre link recebido no WhatsApp
    H->>F: anamnesis/{patientId}.set(...) (form completo)
    Note over F: Regra Firestore:<br/>allow get, write if true (sem auth)<br/>na coleção anamnesis
    F-->>H: sucesso
    H-->>P: confirmação de envio
```

---

## 13. Documentação do Paciente (Upload Cloudinary)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant T as PatientDocsTab
    participant DS as DocumentService
    participant C as Cloudinary
    participant F as Firestore (patients/{id}/docs)

    U->>T: câmera/arquivo + categoria + título
    T->>DS: uploadFile(bytes|file, fileName)
    DS->>C: POST api.cloudinary.com/.../auto/upload<br/>(upload_preset, resource_type=auto)
    C-->>DS: secure_url + public_id + resource_type
    DS->>F: saveMetadata (fileType por extensão,<br/>uploader, publicId)
    F-->>T: stream getDocs atualiza a lista

    U->>T: Excluir documento
    T->>DS: deleteDocument(patientId, docId)
    Note over DS: plano Spark, sem Functions:<br/>sem destroy remoto (órfãos no Cloudinary,<br/>limpeza manual pelo painel)
    DS->>F: docs/{docId}.delete()
```

## Ver tamb�m

- [[foundation/01-prd|PRD]] � produto e riscos
- [[foundation/04-requisitos|Requisitos]] � regras por tr�s dos fluxos
- [[foundation/02-use-cases|CASOS_DE_USO]] � atores de cada fluxo
