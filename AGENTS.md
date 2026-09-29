# OdontoControle - Context Memory for AI Agents

## Project Overview
**OdontoControle** is a Flutter-based dental clinic management system (multi-clinic, multi-role) built for Dra. Lauciele Costa. Supports both dental and psychology clinics.

- **Platform**: Flutter (Web, Android, iOS, Windows, Linux)
- **Backend**: Firebase (Auth, Firestore, Hosting)
- **Architecture**: Multi-tenant with clinic isolation via `clinicId`
- **Languages**: Dart (Flutter), TypeScript (Firebase Functions)

---

## Key Architecture Patterns

### 1. Multi-Clinic Isolation (`SessionManager` + Firestore Rules)
- **SessionManager** (`lib/services/session_manager.dart`): Singleton `ChangeNotifier` holding current user + clinic context
- **All queries MUST filter by `clinicId`** via `SessionManager().applyFilter(query)`
- **Owner** (`role: 'owner'`) sees all clinics; **Staff** (`role: 'receptionist'`, `'dentist'`) restricted to `allowedClinics`
- **Clinic Type** (`dental` | `psychology`) controls UI/menu visibility

### 2. Authentication Flow
```
main.dart → AuthWrapper (StreamBuilder<FirebaseAuth>) 
  → LoginScreen (email/password + role selection on register)
  → RoleCheckScreen (fetches user doc, initializes SessionManager)
  → MainWebDashboard (responsive sidebar navigation)
```

### 3. State Management
- **SessionManager** = global app state (user, clinic, role)
- **Streams** from Firestore for real-time data (`snapshots()`)
- **ValueKey(_currentClinicId)** on screens to force rebuild on clinic switch
- **NO Riverpod/Provider/Bloc** — pure `setState` + `StreamBuilder` + `SessionManager`

---

## Critical Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Firebase init, AuthWrapper, routing |
| `lib/services/session_manager.dart` | **Core** - global session, clinic filter, multi-tenant logic |
| `lib/screens/dashboard/main_web_dashboard.dart` | Main layout, clinic selector, responsive menu, navigation |
| `lib/screens/auth/login_screen.dart` | Login/register, initializes SessionManager on auth |
| `lib/screens/auth/role_check_screen.dart` | Post-login role/clinic resolution |
| `lib/ui/app_theme.dart` | Colors, text styles, ThemeData builder |
| `firestore.rules` | Security rules (owner vs staff, clinic isolation) |
| `lib/services/document_service.dart` | Upload Cloudinary + metadados; destroy via Function `destroyCloudinaryFile` |
| `lib/services/package_billing.dart` | `PackageBilling.compute` puro (billing psico por presença) |
| `lib/screens/psychology/psychology_schedule_form_screen.dart` | Geração de pacote/avulsa + cancelamento de contrato |

### Models (lib/models/)
- `patient_model.dart` - Robust parsing (handles Map/String/Timestamp for address, birthDate)
- `appointment_model.dart` - Includes `clinicId`, `dentistId`, `durationMinutes`
- `budget_model.dart`, `financial_model.dart`, `patient_document_model.dart`, `psychology_schedule_model.dart`, etc. (não existe `treatment_model.dart` — planos são `Map` crus de `treatment_plans`)

### Services (lib/services/)
- `patient_service.dart` - CRUD + risk profile (no-show rate calculation)
- `appointment_service.dart`, `financial_service.dart`, `budget_service.dart`, etc.
- **All services use `SessionManager().applyFilter()` for queries**

---

## Firestore Collections Structure

```
/clinics/{clinicId}           # Clinic metadata (name, type, ownerId)
/users/{uid}                  # role, name, email, allowedClinics[]
/patients/{patientId}         # clinicId required
/appointments/{apptId}        # clinicId, patientId, dentistId, status, attendanceStatus, hasMedicalCertificate, scheduleId, planId, monthlyPeriod
/financial/{docId}            # clinicId, type (income/expense), planId, monthlyPeriod, billingKind (package_monthly|session)
/treatments/{docId}           # clinicId, patientId, plan reference
/treatment_plans/{docId}      # clinicId, patientId, procedures[]
/budgets/{docId}              # clinicId, patientId, items[], status
/clinical_records/{docId}     # clinicId, patientId, content
/lab_orders/{docId}           # clinicId, patientId, labId, status
/procedures/{docId}           # Global catalog (shared)
/inventory/{docId}            # clinicId, productId, quantity
/suppliers/{docId}            # clinicId
/news/{docId}                 # Global ortho news
/expenses/{docId}             # clinicId, description, amount, dueDate, status
/anticipations/{docId}        # histórico de antecipações de recebíveis
/patients/{patientId}/docs/{docId}        # metadados de arquivos (binário no Cloudinary)
/patients/{patientId}/clinical_data/odontogram  # teeth + lastUpdate
/clinics/{clinicId}/leads/{leadId}        # leads da avaliação pública (/avaliacao)
/clinics/{clinicId}/settings/fees         # perfis de taxas de máquina + anticipation_rate
/clinics/{clinicId}/settings/integrations/cloudinary/{config}  # {apiKey, apiSecret} p/ destroy remoto (ausente = só Firestore)
/anamnesis/{patientId}        # Public write (WhatsApp link)
/psychology_schedules/{docId} # Psychology recurring schedules
```

---

## Key Security Rules (firestore.rules)

1. **`isOwner()`** — checks `users/{uid}.role == 'owner'`
2. **`hasClinicAccess(clinicId)`** — checks `clinicId in users/{uid}.allowedClinics`
3. **Operational collections** (patients, appointments, financial, treatments, treatment_plans, budgets, clinical_records, psychology_schedules) require auth + (owner OR clinic access)
4. **Public exceptions**: `/anamnesis` (public write, no auth), `/appointments` update limited to `status='Confirmado'` (+`confirmationDate`, no auth — WhatsApp link)
5. ⚠️ **Regras amplas restantes** (de propósito, p/ não quebrar telas legadas): `procedures` (catálogo global sem `clinicId`), `inventory`/`suppliers` (leitores legados sem filtro), `plans`, `anticipations`, `news`. `financial`/`treatments`/`treatment_plans` valem pela regra F; `expenses`/`lab_orders` têm blocos próprios escopados. Toda query nova DEVE filtrar por `clinicId`.
6. **`clinics/{id}/settings/**`: leitura auth (telas leem taxas); escrita owner. **`settings/integrations/**` (segredos): SÓ owner** — o destroy Cloudinary roda na Function via Admin SDK; o app nunca lê o segredo.
7. Subcoleções `patients/{id}/{docs,odontogram,...}`: auth + (owner OR acesso à clínica do paciente pai).
8. **Anamnese**: `get` público (prefill do html), escrita pública restrita por allowlist de 14 campos; staff auth tem acesso total.

---

## UI/Navigation Patterns

### MainWebDashboard Menu Structure (índices de `_screens`; ordem varia por tipo)
Dental: 0 Dashboard, 1 Agenda, 2 Pacientes, 3 Laboratório, 4 Financeiro, 5 Relatórios, 6 Notícias, 7 Cobranças, 8 Clínicas (owner), 9 Funcionários (owner), 10 Gestão (owner/recep).
Psicologia: 0 Dashboard, 1 Agenda, 2 Pacientes, 7 Cobranças, 11 Fluxo Terapêutico, 4 Financeiro, 5 Relatórios, 6 Notícias (+ 8/9/10 por role); **Laboratório oculto**. Troca de clínica reseta p/ Dashboard se a tela atual sumiu do menu.

### Clinic Type Switching
- `_currentClinicType` state in `MainWebDashboard`
- Item 11 (Fluxo) renders when `ClinicCapabilities.canShowTherapeuticFlow`
- Menu items additionally filtered by `MenuAccess.canShow` (per-user `menuAccess`); hidden selection falls back to Dashboard (`_effectiveIndex`)
- Never compare `clinicType` strings directly — use `ClinicCapabilities`
- `SessionManager().setClinic(id, name, type)` updates both

---

## Recent Changes (Sep 2026)

### Multi-tenant centralizado
- `clinic_capabilities.dart` — `isPsychology/isDental`, `canShowBudgets/Lab/Odontogram`, `canUseMonthlyPackages`, `professionalRole`, `patientTabCount`
- `AgendaCellFactory` — célula vazia da agenda abre o form certo sem `if clinicType` espalhado
- `ScheduleRepository.watchByClinic` — visão unificada dental+psico sem fundir collections

### Pacotes psicologia — billing por presença (decisões travadas)
1. Mês incompleto cobra **parcial** · 2. Divisor = sessões **previstas** · 3. Falta **com atestado não conta** (nem no risco) · 4. Desconto de terceiro entra **antes** do rateio
- `package_billing.dart` — `PackageBilling.compute` (puro, sem Firebase)
- `appointments`: `scheduleId/planId/monthlyPeriod/attendanceStatus/hasMedicalCertificate`
- `financial`: `billingKind: package_monthly|session` (+ `monthlyPeriod` legado)
- Cobrança `Por Sessão` exclui pacotes; card mensal com `BillingSkeleton` + timeout 5s; `paid` congela o valor
- **Avulsa gera 1 sessão só** na data selecionada (sem recorrência)
- Finalizar psico: sem dropdown de procedimento (vínculo automático ao `planId`); checkbox **Apresentou Atestado** na falta

### Pacientes / cobrança
- Header da ficha com 4 cards (assiduidade, A Receber = valor−pago, Recebido, Custo Operacional); cards da aba Pagamentos removidos
- Aba Pagamentos: filtros (valor mín/máx, procedimento) em bottom sheet + toggle de ordenação (padrão: vencimentos próximos)
- `deletePatientCascade` via `_cascadeCollections`; risco isenta falta com atestado
- Ficha: dental = **9 abas**, psicologia = **6 abas** (sem ORÇAMENTOS/ODONTOGRAMA/LABORATÓRIO)

### Documentos (Cloudinary)
- Upload unsigned p/ `https://api.cloudinary.com/v1_1/dbbh601ay/auto/upload` (`upload_preset=dbbh601ay`, `resource_type=auto`); metadados em `patients/{id}/docs`
- Exclusão apaga **só o Firestore** (plano Spark, sem destroy remoto — binários viram órfãos; limpeza manual ocasional pelo painel Cloudinary); `purgePatientFiles` só loga a contagem, após o commit OK em blocos de 450

### Registro e avaliação pública
- Novo cadastro nasce com `allowedClinics: []` + `status: 'pending_approval'` — owner libera em Funcionários (antes caía hardcoded com acesso imediato)
- `/avaliacao` sem `?cid=` mostra "Clínica não encontrada" (antes gravava lead de teste na clínica real)

### Cancelamento de contrato psico
- Botão no modo edição do form: futuras não finalizadas → `Cancelado`, financeiros `pendente/pending` do plano → `Cancelado`; finalizados/pagos intactos; batch em blocos de 450. Edição **não regenera** agenda/financeiro.

### Gestão: aba Configurações + menu psico
- 5ª aba (CONFIGURAÇÕES): tema claro/escuro por aparelho + controle de acesso (`menuAccess` por usuário, filtrado por tipo via `keysForClinicType`; owner edita/ignora)
- Tema: `ThemeController` (preferência por usuário em `user_prefs/{uid}` + fallback do aparelho) + `AppColors` adaptativo + `buildAppTheme(dark:)`; telas com cor hardcoded não seguem o escuro (fase 2)
- Menu psico: Dashboard, Agenda, Pacientes, Cobranças, Fluxo, Financeiro, Relatórios (+Notícias); Laboratório oculto; troca de clínica reseta seleção órfã

### Limpeza
- Deletados: `leads/`, `mock_data_service`, `psychology_schedule_list_screen`, `psychology_schedule_service`, `agenda_form_screen copy`, `patient_financial_tab copy*`
- Deletados (code-simplifier): `utils/app_constants.dart` (morto + valores errados), `payment_service.receivePayment`, `_checkForGroupPayment`, `_showMonthlyValueDialog`, `_createNewProfile`, `_buildMinimalistCard`, `_getInitials`, `_isLoadingData`, imports/campos mortos; rules `plans/anticipations` removidas
- Helpers puros em `utils/display.dart` (`parseBRL`, `daysAgoLabel`, `slotCardColor`, `chargeBadgeColor`) + `relatedDocs()` na fin_tab; ternários aninhados eliminados
- `firestore.indexes.json` reformatado (removida duplicata `appointments`)
- `widget_test.dart` usa `ClinicApp`; `print` → `debugPrint`; `withOpacity` → `withValues`

### Pending Firestore Index Deploy
- `firestore.indexes.json` mesclado (console + novos filtros) — fonte da verdade; **nunca aceitar delete** no deploy (`No`)
- Run: `firebase deploy --only firestore:rules,indexes` (rules liberam `user_prefs` p/ o tema por usuário)

### Hosting layout (build/web)
- App em `/sistema-interno/` (`--base-href`); raiz: `index.html` (landing), `anamnese.html`, `confirmar.html`, `portal.html`, `assinatura.html`, `logo.png`.
- `deploy.bat`: build → move app p/ `sistema-interno/` → landing vira `index.html` → `firebase deploy --only hosting --project=nexosaude`.
- Páginas públicas (`portal/assinatura/landing`): HTML estático + Firebase compat, sem build; deploy direto copiando p/ `build/web/`.

---

## Psychology Package Billing (implemented — see obsidian/PSYCHOLOGY_PACKAGES.md + `obsidian/modules/psychology-packages.md`)

---

## Common Development Commands

```bash
# Install dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run on Windows
flutter run -d windows

# Build web for Firebase Hosting
flutter build web --release

# Deploy to Firebase
firebase deploy

# Analyze code
flutter analyze

# Run tests
flutter test

# Generate firebase_options.dart (after firebase config changes)
flutterfire configure
```

---

## Important Conventions

### Adding New Screens
1. Add to `_screens` list in `MainWebDashboard` with `ValueKey(_currentClinicId)`
2. Add menu item in `_buildMenuContent()` with role/clinic-type guards
3. Service queries **must** use `SessionManager().applyFilter(query)`

### Data Models
- All models have `fromMap(id, map)` with **defensive parsing** (handle null, Map, Timestamp, String)
- All models include `clinicId` field
- `toMap()` returns Firestore-compatible map with `Timestamp.fromDate()`

### Error Handling
- Models parse gracefully (e.g., `parseAddress`, `parseBirthDate` in PatientModel)
- Services return safe defaults on error (e.g., `getPatientRiskProfile` returns `{'level': 'green', 'missed': 0}`)
- UI shows SnackBar for auth/network errors

### Firebase Functions
- **Plano Spark: sem backend** — `functions/` removido (deploy de Functions exige Blaze); `firebase.json` sem o bloco `functions`
- Se um dia migrar p/ Blaze: recriar `destroyCloudinaryFile` (callable auth + segredo via Admin SDK) e apontar `DocumentService.deleteRemoteFile` p/ ela

---

## Known Gotchas

1. **ClinicId missing** → `SessionManager.applyFilter()` returns query matching `'waiting_session_init'` (empty results)
2. **Address field** in Firestore can be String OR Map → `PatientModel.parseAddress()` handles both
3. **BirthDate** can be String OR Timestamp → `parseBirthDate()` handles both
4. **RoleCheckScreen** runs on every app start (auth state change) — keep it fast
5. **ValueKey(_currentClinicId)** forces screen rebuild when clinic switches
6. **Owner clinic selector** auto-selects first clinic if none selected
7. **`patientTabCount` deve espelhar as abas renderizadas** (dental 9 / psico 6 / default 9) — divergência quebra o `DefaultTabController` (bug corrigido em Sep 2026: era 7/8)

---

## Environment / Config
- `lib/firebase_options.dart` - Auto-generated, **do not edit manually**
- `firebase.json` - Hosting redirects (root → external site, `/sistema-interno/**` → SPA)
- `firestore.indexes.json` - Composite indexes for queries
- `.firebaserc` - Project alias (`default = nexosaude`; `odontocontrole` = antigo, backup)

---

## When Working on This Project

1. **Always check `SessionManager`** for current clinic context
2. **Filter every Firestore query** with `SessionManager().applyFilter()`
3. **Test with multiple clinics** (owner + staff accounts)
4. **Verify Firestore rules** after adding new collections
5. **Use defensive parsing** in models (see `PatientModel` for pattern)
6. **Read `obsidian/00-index.md` first** — one skill-file per module/screen with flows and gotchas; update the skill when behavior changes

---

## 🧠 War Room Hexagonal (Modo de Alta Performance)

Ao receber tarefas de **planejamento, arquitetura, design de solução ou decisão de trade-offs**, adote o papel de uma equipe de 6 especialistas seniores e siga o processo:

### Os 6 Especialistas
1. 🏗️ **Staff Architect** — Escalabilidade, nuvem, custos, Big Picture.
   Lema: "Isso aguenta 1 milhão de usuários?"
2. 🛡️ **QA & SecOps** — Bugs antes de codificar, LGPD, segurança de API/testes.
   Lema: "Onde quebra e como hackeiam a gente?"
3. 👨‍💻 **Tech Lead / Senior Dev** — Clean Code, padrões de projeto, performance Flutter.
   Lema: "Funciona limpo e performático."
4. 💼 **Product Manager** — Valor de negócio, priorização (MVP), ROI.
   Lema: "Isso traz dinheiro ou resolve dor real?"
5. 🎨 **Product Designer** — Jornada do usuário, acessibilidade, usabilidade.
   Lema: "O usuário usa sem pensar?"
6. 🚀 **Growth Hacker** — Venda, retenção, viralização.
   Lema: "Como vira ímã de clientes?"

### Processo de Debate
1. **Checkpoint de Risco/Oportunidade** — cada agente analisa (QA/SecOps primeiro).
2. **Conflito Construtivo** — Arquitetura valida Dev; Produto valida custo do Design.
3. **Veredito Unificado** — equilíbrio Custo × Segurança × Usabilidade.
4. **Blueprint de Execução** — Arquitetura + Código (production-ready) + Plano de Testes.

### Regras de Ativação
- Ativar War Room **por padrão** em: planejamento, arquitetura, novas features, correções críticas, decisões de trade-off.
- **Não ativar** em: perguntas rápidas, edições simples, leitura/consulta de código.
- A pessoa ainda escolhe o **alvo do debate** a cada vez (ex.: "War Room sobre <tema>").