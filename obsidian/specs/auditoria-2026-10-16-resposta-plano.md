# Resposta à auditoria de 16/10/2026 + plano de execução

Avaliação ponto a ponto contra o código atual (`remodelagem-gpt` ≈ `master`
+ trabalho em curso). Convenção: ✅ confirmado · ⚠️ parcial ·
❌ refutado · 🔀 já corrigido na remodelagem (falta merge).

## Veredito por achado

| # | Achado da auditoria | Veredito |
|---|---|---|
| P0 | `owner` global sem `ownerId`/`allowedClinics` | ✅ confirmado (rules F + `isOwner()` só lê `role`). Na prática cada clínica tem 1 owner (`ownerId`), mas a regra não impõe — com N owners SaaS, é crítico |
| P0 | Escrita anônima em `appointments` só com o ID | ✅ confirmado (regra D sem auth nem token). Igual ao P1 da Fase 3 da remodelagem |
| P1 | `users`/`clinics` leitura ampla; `inventory`/`suppliers` escrita ampla | ✅ confirmado (texto das regras). Idem P2 da Fase 3 |
| P1 | Rebuild sem `clinicId` "tende a ser negado" p/ staff | ⚠️ parcial: rules avaliam por documento, então staff COM acesso recebe; o problema real é outro — erro engolido em `debugPrint` + `limit(100)` sem ordem |
| P1 | Fallback do pacote mensal cobra o cheio | ✅ confirmado (`collections_screen.dart:707-732`: em erro, o card continua tocável com `totalAmount = packageAmount`) |
| P2 | `debtsTotal` soma o cheio | ✅ em `master`/`producao`, mas 🔀 já corrigido (fase2: resto + teste) — falta merge |
| P2 | `portal_slots` com `read` (permite `list`) | ✅ confirmado. Ninguém lista no app → trocar por `get` é seguro |
| P2 | AGENTS.md × Cloudinary (`destroyCloudinaryFile`) | ✅ confirmado (`document_service.dart:136-141` retorna `false`; órfãos documentados no código) |
| P2 | Sem testes de rules/emulador | ✅ confirmado; emulador indisponível aqui (sem Java) — ver plano |
| §4 | README pendente rules/indexes | 🔀 já corrigido na remodelagem (`6d3bbed`); `master` ainda stale |
| §4 | Kanban com prazos 02–06/10 em "A Fazer" | ✅ confirmado (nx-101/102 feitos no backlog, Kanban parado) |
| §4 | `LGPD.md` mistura feito × proposto | ✅ procedente — reestruturar em 3 blocos |

## Plano de execução (branch `remodelagem-gpt`, sem publicar nada sem ordem)

### Etapa A — sem rules, sem risco (fazer já)
1. `AGENTS.md`: trocar Function por "destroy desabilitado, órfãos manuais".
2. `LGPD.md`: 3 blocos (verificado no código / depende de produção / proposta).
3. Kanban: nx-101/102 → concluído com evidência; nx-103 (venceu 06/10) → reagendar ou executar.
4. `portal_slots`: `allow read` → `allow get` (proposta pronta; publicar junto da Etapa B).
5. Rebuild (`portal_mirror.dart`): passar `clinicId`, erro observável (toast/log em vez de só `debugPrint`), trocar `limit(100)` por janela de datas + ordenação.

### Etapa B — código de cobrança (fazer já)
6. Pacote mensal: query por `planId` + `clinicId`; em erro/timeout, **desabilitar** a cobrança (sem valor cheio como fallback) + teste do gate.
7. Merge do já pronto: `debtsTotal` resto, README, portal resto/Pix (fase2).

### Etapa C — rules (ARQUIVO alterado, NÃO publicado)
8. ✅ no arquivo: `appointments` anônimo exige `portalToken` vinculado (+ `confirmar.html?t=`, link com token e `portal.html` enviando; staff autenticado inalterado). Links antigos sem token caem no fallback "avise no WhatsApp".
9. ✅ no arquivo: `portal_slots` com `allow get` (lista só autenticado; ninguém lista).
10. ✅ FEITO em 16/10 e PUBLICADO (`f50ad0ac` ~20:50Z, ordem explícita): auditoria escritor-a-escritor (todos os escritores carimbam `clinicId`); owner global removido da regra F, expenses/lab, delete de clínica, write de settings/fees, subcoleções via `patientClinicOk`; leitura de `users` autenticada (list) + get escopado; escrita de procedures/suppliers/inventory exigindo `clinicId` escopado (base verificada — seguro). Mantidos então: leitura de `clinics`, anamnese pública, creates de `users` (revistos na reavaliação da noite — ver seção abaixo).
11. ✅ PUBLICADO em 16/10/2026 (ordem explícita): ruleset `a6883496-5be1-4421-9e53-76d86067d4d7` via `rules-release.js`, confirmado via `rules-inspect.js`. Anterior (rollback): `fb8cc262-ebcf-4db4-b173-30297ae4ae2d` (fonte salva em Temp/live-firestore.rules).
12. ⚠️ REVERSÃO PARCIAL em 16/10 (~17:10): leitura de `users` voltou a autenticada (ruleset `9a7990e0`). Motivo: escopo por sobreposição nega a LISTA inteira (tudo-ou-nada) — quebrou dropdown da agenda e `ensureWindow` (erro `PortalMirror janela falhou`). `sharesClinic` mantida SÓ p/ gets. Residual aceito e documentado na regra (UIDs imprevisíveis, app filtra por clínica, sem credenciais nos docs).
11. Publicar via `migrate/rules-release.js` + `rules-inspect.js` SOMENTE com ordem explícita.

### Etapa D — verificação sem emulador
12. Sem Java aqui: protocolo manual no Console (matriz anônimo × staff sem acesso × staff × owner × owner de outra clínica × superadmin, contra `appointments`, `financial`, `portal`, `users`, `settings`) com checklist assinado. Emulador fica como pendência de infra (não de código).

### Etapa E — entrega
13. `flutter analyze` + `flutter test` + build web na branch.
14. Merge `remodelagem-gpt → master → producao` + `deploy.bat` (tudo com ordem).

## O que a auditoria errou ou exagerou
- Rebuild "negado p/ staff": o mecanismo descrito não procede (avaliação é por documento); os defeitos reais são observabilidade e limite — menores e já endereçados acima.
- `debtsTotal`, README e parte do portal: apontados como pendentes, mas já implementados na remodelagem — o gap é merge, não código.

## Reavaliação 16/10 (noite, `reavaliacao-2026-10-16-master`) — segundo lote

Estado: rules ARQUIVO (não publicado; ao vivo segue `f50ad0ac` até matriz + ordem).

| Item | Disposição |
|---|---|
| P0 anamnese pública | ✅ sem get/list anônimo; escrita só com `proofToken == patients/{id}.anamnesisToken` + tipos/tamanhos; link `?id=&t=`; prefill público removido |
| P1 create clínica nega owner | ✅ `_noClinicAdminKeys` recebe `.keys()`; owner exige `type` válido; matriz cobre create owner/com-trial/superadmin |
| P1 menuAccess self-grant | ✅ fora do self-update (só team-manage); `clinicActive` no update operacional (dono e staff); matriz cobre |
| P1 login ignora status | ✅ pendente → tela de espera (sem dashboard/listas); inativo → logout; rules exigem `status == 'Ativo'` (listas, acesso, shares) |
| P1 revogação portal | ✅ `apptTokenOk` só contra o token ATUAL do paciente; token velho no agendamento não vale; matriz testa |
| P1 assinatura uid scope | ✅ `let uid` fora do try; limpeza de órfão executa |
| P1 public_clinics onboarding | ✅ Master web (aprovar + novo owner), Master Flutter e app criam/espelham; renomeações futuras devem re-espelhar |
| P1/P1 users/clinics/reset | ✅ lists só perfil ATIVO; reset global só Master (aba Resets) + fila interna por clínica; temporária NUNCA persiste (só console do bat) |
| P1 trialEndsAt null | ⚠️ 2 clínicas reais sem trial (Yervant, Jabaquara) — política+backfill em `nx-172` (sem escrita automática) |
| P2 debtsTruncated | ✅ portal.html avisa "pode estar incompleto" |
| P2 leads spam | ✅ teto 2k no join das respostas; rate limit real exige backend (residual) |
| P2 CI | ✅ workflow manual `ci-manual.yml` (dispatch); auto segue removido por decisão |
| P2 higiene | ✅ `node_modules/` raiz + cache hosting fora do índice; `.gitignore` cobre |
| P2 Cloudinary órfãos | ✅ rotina documentada em `nx-174` (limpeza manual periódica) |

## Reavaliação 16/10 (tarde, `reavaliacao-2026-10-16`) — primeira leva (PUBLICADA em `f50ad0ac`)

Arquivo: [[reavaliacao-2026-10-16]] (fotografia histórica).

| Item | Disposição |
|---|---|
| P0-1 owner→superadmin | ✅ `role` imutável via cliente; update/delete de `users` por papéis (self-perfil, team-manage, superadmin); create com allowlist |
| P0-2 financial/appointments/portal/anamnesis | ✅ staff exige `clinicScoped`; anônimo só allowlist + token; delete anamnese escopado |
| P1-3 trial/bloqueio | ✅ owner sem admin-keys (create e update); `clinicActive` enforceable nas rules; `role_check` fail-closed (tela indisponível + retry) |
| P1-4 trial `uid` | ✅ rule aceita `uid == auth.uid` + validações; `assinatura.html` valida WhatsApp e limpa órfãos (doc pendente apagável pelo próprio) |
| P1-5 token confirmação | ✅ app carimba `portalToken` (service + psico batch); regra aceita token do agendamento OU do cadastro |
| P1-6 avaliação pública | ✅ `public_clinics/{id}` (get público, sem list) + leads anônimos validados; tela migrada; clínica espelha ao criar |
| P1-7 residuais | ✅ slots sem list + escrita escopada; inventory/suppliers exigem `clinicId` (base verificada: 0+12 com campo); settings/fees/integrations escopados; news só superadmin; reset escopado quando tem clínica |
| P2-8 slots parcial | ✅ ver acima |
| P2-9 espelho | ✅ ASC + índice novo em `indexes.json`; financial teto 500 + `debtsTruncated`; sem-clínica = erro observável; 5 chamadores com toast |
| P2-10 gate pacote | ✅ teste widget do card de erro (`monthly_package_card_test.dart`); manual registrado no plano §6 |
| P2-11 Cloudinary | ✅ `AGENTS.md` afirmação única correta (sem Function; destroy desabilitado; órfãos manuais) |
| P2-12 docs/release | ✅ README + plano de testes atualizados; `migrate/rules-*.js` portáteis e versionados (chave ignorada); Kanban nx-103 reagendado |
| P2-13 rules/CI | ✅ matriz `test/rules/matrix.test.js` (14 casos) + `firebase.json` emulators + workflow CI (flutter + rules) |

**Desvios assumidos (documentados nas rules):** `users` list e `clinics` list seguem autenticadas (tudo-ou-nada + fluxos `role_check`/assinatura/mainView exigem; sem dado de paciente); trial `null` = ativa (legadas + 2ª unidade; backfill pendente); links antigos sem `t` caem no WhatsApp (sem segredo, sem auth); reset anônimo do login segue visível a owner (só e-mail transitório, app apaga após processar).
