# Plano de testes — remodelagem-gpt (fases 1–4 + auditoria 16/10 + reavaliação 16/10)

Escopo: `master` após a reavaliação (rules P0–P2 reescritas, app ajustado).
Ambiente: checkout + `flutter run -d chrome`. Emulador/CI p/ rules:
`firebase emulators:exec --only firestore "npm --prefix test/rules test"`
(Java indisponível nesta máquina — roda no CI). **NADA vai a produção
sem este plano assinado. Rules NOVAS NÃO publicadas** (ao vivo segue
`d28dd75b` até a matriz passar + ordem explícita).

## 0. Base automatizada (executar primeiro)

- [x] `flutter analyze --no-pub` → 227 issues, 0 erros (16/10, +1 info vs baseline).
- [x] `flutter test` → +177 tudo verde (16/10; `widget_test` corrigido com Firebase mockado + gate `monthly_package_card` + flag `debtsTruncated`).
- [x] Matriz `test/rules/matrix.test.js` no emulator (14 casos P0/P1) → tudo verde. **Bloqueia o release.**
- [x] `node migrate/rules-validate.js` → SINTAXE OK (sem release).
- CI verde em 16/10 (~20:38Z, run `38963424437`): jobs `flutter` (analyze 0 erros + suite +177) e `rules` (matriz 14/14 no emulator) ✓. No caminho, a matriz pegou 2 defeitos reais já corrigidos: `Set.toSet()` no team-manage (negava tudo) e massa do trial fora da allowlist.

## 1. Fase 1 — diálogos em telas pequenas

Para cada largura (DevTools → 320, 360, 390, 430) e cada diálogo,
abrir e confirmar: sem faixa amarela de overflow, sem corte, botões
clicáveis; repetir com teclado virtual aberto (clicar num campo).

| # | Diálogo (como abrir) | Esperado |
|---|---|---|
| 1.1 | Agenda → evento → Finalizar Atendimento | Cabe na largura, rola vertical |
| 1.2 | Funcionários → Novo Funcionário | Idem |
| 1.3 | Ficha → Documentação → Novo Pedido Lab | Idem |
| 1.4 | Orçamentos → Aprovar (wizard) | Passa as 3 etapas sem corte |
| 1.5 | Agenda → Novo → cadastro rápido (+) | Idem, com teclado aberto |

## 2. Fase 2/4 — portal e saldo restante

Preparar massa (clínica Teste): cobrança de R$ 200 com R$ 80 pagos
(legada: `amount` cheio + `paidAmount`), e parcial nova via app.

| # | Passo | Esperado |
|---|---|---|
| 2.1 | Portal do paciente → A receber | Linha mostra **R$ 120,00** + "falta R$ 120,00 de R$ 200,00" |
| 2.2 | Total em aberto | Soma dos restos, não dos cheios |
| 2.3 | Pagar com Pix → código | Valor do QR = R$ 120,00 |
| 2.4 | Confirmar/remarcar sessão | Fluxo inalterado; pedido ≠ concluído |
| 2.5 | Link revogado | "Link inválido ou revogado" |

## 3. Fase 4 — app (WhatsApp, oracle, linha)

| # | Passo | Esperado |
|---|---|---|
| 3.1 | Cobranças → WhatsApp na parcial legada | Mensagem cita R$ 120,00 (resto) |
| 3.2 | Ficha → WhatsApp Cobrar (mesma) | Idem |
| 3.3 | Livro Caixa → linha da parcial | Valor = resto; pago = cheio |
| 3.4 | Projeção/saldo | Não conta o já pago duas vezes |
| 3.5 | Filtros Recebido/A Receber/Inadimplente | Classificação inalterada |

## 4. Regressão (fluxos que não mudaram)

- [ ] Agenda: criar/editar/cancelar/bloquear/liberar evento.
- [ ] Receber à vista, parcelar no cartão, estornar, cancelar família.
- [ ] Portal: confirmar presença, pedir remarcação, avisar pagamento.
- [ ] Login por perfil (owner, dentista, recepcionista) + menu correto.

## 5. Segurança (matriz antes de publicar)

- [ ] Ruleset ao vivo AINDA `d28dd75b`: `node migrate/rules-inspect.js` → mesmo id (nada publicado durante os testes).
- [ ] Matriz `test/rules/` verde no emulator (anon/staff mesma/staff outra/owner outra/superadmin).
- [ ] Manual pós-matriz (conta de teste por perfil): dropdown da agenda lista; confirmar por link com token; avaliação pública carrega + grava lead; owner NÃO promove a si; clínica bloqueada nega operacional no app.

## 6. Auditoria 16/10 (lote `a5458a7`)

- [ ] Pacote mensal com cálculo quebrado: card mostra "Cálculo
      indisponível... toque para tentar" e o toque **NÃO cobra**
      (só recalcula). Cobrança normal com cálculo OK inalterada.
- [ ] Portal com parcial: valor, total e Pix = resto (repetir §2).
- [ ] Rebuild: portal reflete após escrita (sem erro mudo).
- [ ] Confirmar por link **com token** (`confirmar.html?id=X&t=Y`)
      confirma; link antigo sem token cai no "avise no WhatsApp".
- [ ] Confirmar/remarcar pelo portal funcionam (token enviado).
- [ ] Staff (recepcionista): rebuild e pacote funcionam (comportamento
      igual ou melhor que antes).

## 7. Reavaliação 16/10 (lote atual — regressão dirigida)

- [ ] Login owner/staff/superadmin + trava de assinatura (bloqueio manual e trial vencido mostram tela; falha de leitura mostra "indisponível", NÃO entra).
- [ ] Funcionários: criar staff (vincula à clínica), editar clínicas, pedir reset (com `clinicId`), dispensar pedido.
- [ ] Trial: cadastro `assinatura.html` cria pedido COM `uid` (Master vê e aprova); falha no pedido NÃO deixa órfão (tenta de novo no mesmo e-mail).
- [ ] Avaliação pública `?cid=`: carrega nome/WhatsApp SEM login; responde e grava lead; WhatsApp abre com score.
- [ ] Agenda cria agendamento COM `portalToken` (checar doc); confirmar por link com token funciona; remarcar idem.
- [ ] Espelho: falha aparece em toast (não só console); `debtsTruncated` quando 500+ lançamentos.
- [ ] Exportação (owner) e Master seguem operando (lists autenticadas mantidas).

## Assinatura

| Item | OK? | Obs |
|---|---|---|
| Base 0 verde (analyze 0 erros + suite +177) | ☑ | 16/10 máquina local |
| Matriz de rules no emulator | ☑ | 16/10 CI run 38963424437 (14/14) |
| Fase 1 (5 diálogos × 4 larguras) | ☐ | |
| Fase 2 (portal resto/Pix) | ☐ | |
| Fase 4 (valores restantes) | ☐ | |
| Regressão §4 + §7 | ☐ | |
| Segurança verificada (§5) | ☐ | |

Só após tudo ☐→☑: `rules-release.js` + `firestore:indexes` (com ordem explícita) → merge `master → producao` + `deploy.bat` (com ordem explícita).
