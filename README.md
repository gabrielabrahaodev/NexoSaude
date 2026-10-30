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

- **Documentos clínicos / Cloudinary legado:** novos uploads diretos unsigned estão bloqueados no Flutter por segurança. Esse bloqueio NÃO desativa o preset no Cloudinary: terceiros ainda podem enviar arquivos diretamente enquanto o preset continuar unsigned/ativo no painel. Desative/restrinja o preset no provedor antes de considerar o risco contido. Os metadados antigos ainda podem apontar para URLs de CDN do Cloudinary; quem tiver a URL pode conseguir abrir o arquivo independentemente das Firestore Rules. A exclusão remota segue indisponível no cliente e o app preserva os metadados se não conseguir apagar o binário. Antes de reativar uploads, implante endpoint privado/autenticado de upload/delete ou migre para armazenamento privado; inventarie e migre os arquivos antigos.
- **Limpeza Cloudinary legado:** primeiro simule `node migrate/delete-cloudinary-document.js --clinic CID --patient PID --document DID`; a exclusão real exige backup/revisão e `--apply --confirm-delete CID/PID/DID`, além das variáveis `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` e `CLOUDINARY_API_SECRET` no ambiente local. O script só remove metadata depois de uma resposta de sucesso do Cloudinary e remove um arquivo por chamada.

- **Links públicos**: `confirmar.html?id=&t=` (presença) e `anamnese.html?id=&t=` (anamnese/token dedicado) ficam na raiz do hosting; `/avaliacao?cid=` lê `public_clinics/{cid}` e grava leads em `public_clinics/{cid}/leads`. O portal exige token atual + aceite LGPD. Antes de publicar as Rules, rode `node migrate/portal-backfill-patient-id.js` e `node migrate/clinic-members-backfill.js` em dry-run, revise as contagens e só então execute cada um com `--apply`.

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
