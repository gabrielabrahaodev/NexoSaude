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
10. ⏳ PENDENTE (exige auditoria escritor-a-escritor): owner escopado por `ownerId`, `users`/`clinics` leitura escopada, `inventory`/`suppliers` escrita escopada. NÃO implementar às cegas (risco: telas owner-ALL sem filtro negariam).
11. Publicar via `migrate/rules-release.js` + `rules-inspect.js` SOMENTE com ordem explícita.

### Etapa D — verificação sem emulador
12. Sem Java aqui: protocolo manual no Console (matriz anônimo × staff sem acesso × staff × owner × owner de outra clínica × superadmin, contra `appointments`, `financial`, `portal`, `users`, `settings`) com checklist assinado. Emulador fica como pendência de infra (não de código).

### Etapa E — entrega
13. `flutter analyze` + `flutter test` + build web na branch.
14. Merge `remodelagem-gpt → master → producao` + `deploy.bat` (tudo com ordem).

## O que a auditoria errou ou exagerou
- Rebuild "negado p/ staff": o mecanismo descrito não procede (avaliação é por documento); os defeitos reais são observabilidade e limite — menores e já endereçados acima.
- `debtsTotal`, README e parte do portal: apontados como pendentes, mas já implementados na remodelagem — o gap é merge, não código.
