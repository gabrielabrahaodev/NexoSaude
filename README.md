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
Rules/índices: ao vivo = ruleset `f50ad0ac` + índices (16/10, release reavaliação P0–P2, matriz 14/14 no CI). Scripts versionados em `migrate/rules-*.js` (chave via `GOOGLE_APPLICATION_CREDENTIALS` ou `migrate/*-key.json` local, ignorado no git). Validação manual antes de publicar: `flutter analyze` (0 erros) + `flutter test` + matriz `test/rules/` no emulator (`firebase emulators:exec --only firestore "npm --prefix test/rules test"`, precisa Java 21+). Publicar SÓ com ordem explícita.

## Integrações (setup manual)

- **Cloudinary** (docs do paciente): upload unsigned — cloud `dbbh601ay`, `upload_preset=dbbh601ay` (preset precisa estar **unsigned** no painel). Exclusão apaga só o Firestore (Spark, sem destroy remoto).
- **Links públicos**: `confirmar.html?id=&t=` (presença, token do paciente) e `anamnese.html?id=` (anamnese) ficam na raiz do hosting; `/avaliacao?cid=` (rota Flutter) lê `public_clinics/{cid}` e grava leads em `public_clinics/{cid}/leads`.

## Estrutura

- `lib/screens/` — telas por domínio (`agenda/`, `patients/`, `financial/`, `psychology/`, …)
- `lib/services/` — regras (`session_manager`, `clinic_capabilities`, `package_billing`, …)
- `lib/models/` — `fromMap` defensivo em todos
- `brain/` — **leia primeiro**: 1 MD por módulo/tela (`00-index.md` é o mapa)
- `AGENTS.md` — memória de contexto (arquitetura, coleções, convenções)
- `CASOS_DE_USO.md`, `Requisitos.MD`, `DIAGRAMAS_DE_SEQUENCIA.md`, `PSYCHOLOGY_PACKAGES.md`

## Convenções

- Toda query operacional filtra por `clinicId` (`SessionManager().applyFilter`)
- Decisões por tipo de clínica via `ClinicCapabilities` (nunca `if clinicType` solto)
- Status financeiro: `pending/pendente`, `paid`, `anticipated`, `cobrado`
- Presença: `attendanceStatus` (`Attended`/`Missed`) + `hasMedicalCertificate`
