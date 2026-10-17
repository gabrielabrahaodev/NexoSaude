# NexoSaúde

Sistema multi-clínica (odontologia, psicologia) em Flutter + Firebase:
agenda, pacientes, prontuário, financeiro, cobrança via WhatsApp e relatórios.

## Stack

- Flutter (Web, Android, iOS, Windows, Linux) · Firebase (Auth, Firestore, Hosting)
- Sem gerenciador de estado externo: `setState` + `StreamBuilder` + `SessionManager`

## Começo rápido

```bash
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
```

Deploy web: `deploy.bat` (build + organiza `/sistema-interno/` + `firebase deploy --only hosting`).
Branches: `master` (próximas sprints) e `producao` (= ao vivo); deploy roda da `producao`.
Rules/índices: ao vivo = ruleset `3051b8d5` + índices (16/10 noite, 2º lote, matriz 20/20). Scripts em `migrate/rules-*.js` (chave via `GOOGLE_APPLICATION_CREDENTIALS` ou `migrate/*-key.json` local, ignorado no git). Publicar SÓ com ordem explícita.

## Integrações (setup manual)

- **Cloudinary** (docs do paciente): upload unsigned — cloud `dbbh601ay`, `upload_preset=dbbh601ay` (preset precisa estar unsigned no painel). Validação de tipo/tamanho no Flutter é contornável pelo cliente; excluir metadados no Firestore não exclui o binário. Restringir o preset e planejar upload/delete autenticado antes de usar com documentos sensíveis.
- **Links públicos**: `confirmar.html?id=&t=` (presença, token atual do paciente) e `anamnese.html?id=&t=` (anamnese, token dedicado) ficam na raiz do hosting; `/avaliacao?cid=` lê `public_clinics/{cid}` e grava leads em `public_clinics/{cid}/leads`. O portal exige correspondência com o token atual e aceite LGPD; antes de publicar as Rules novas, executar `node migrate/portal-backfill-patient-id.js` (dry-run), revisar e então `--apply`.

## Estrutura

- `lib/screens/` — telas por domínio (`agenda/`, `patients/`, `financial/`, `psychology/`, …)
- `lib/services/` — regras (`session_manager`, `clinic_capabilities`, `package_billing`, …)
- `lib/models/` — `fromMap` defensivo em todos
- `obsidian/00-index.md` — índice da documentação por módulo/tela (leia primeiro).
- `AGENTS.md` — memória de contexto (arquitetura, coleções, convenções)
- `CASOS_DE_USO.md`, `Requisitos.MD`, `DIAGRAMAS_DE_SEQUENCIA.md`, `PSYCHOLOGY_PACKAGES.md`

## Convenções

- Toda query operacional filtra por `clinicId` (`SessionManager().applyFilter`)
- Decisões por tipo de clínica via `ClinicCapabilities` (nunca `if clinicType` solto)
- Status financeiro: `pending/pendente`, `paid`, `anticipated`, `cobrado`
- Presença: `attendanceStatus` (`Attended`/`Missed`) + `hasMedicalCertificate`
