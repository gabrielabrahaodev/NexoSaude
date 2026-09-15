# OdontoControle

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
