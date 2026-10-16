# Plano de testes — remodelagem-gpt (fases 1–4 + auditoria 16/10)

Escopo: branch `remodelagem-gpt` (9 commits após `a6bad4f`). Ambiente:
checkout da branch + `flutter run -d chrome`. Sem emulador (sem Java):
testes de rules fora; resto manual + suite unitária. Nada vai a produção
sem este plano assinado. **Rules NÃO publicadas** (ver §6).

## 0. Base automatizada (executar primeiro)

- [ ] `flutter analyze --no-pub` → 226 issues, 0 erros (igual baseline).
- [ ] `flutter test` → +174 -1 (só `widget_test` pré-existente).
- [ ] `flutter test test/portal_mirror_test.dart` → parcial conta resto.

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

## 5. Segurança (só verificação, sem publicar)

- [ ] Ruleset ao vivo inalterado: `node migrate/rules-inspect.js` →
      mesmo id de 27/09 (ou o publicado depois, se autorizado).
- [ ] P1/P2 seguem como proposta NÃO aplicada.

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

## Assinatura

| Item | OK? | Obs |
|---|---|---|
| Base 0 verde | ☐ | |
| Fase 1 (5 diálogos × 4 larguras) | ☐ | |
| Fase 2 (portal resto/Pix) | ☐ | |
| Fase 4 (valores restantes) | ☐ | |
| Regressão | ☐ | |
| Segurança verificada | ☐ | |

Só após tudo ☐→☑: merge `remodelagem-gpt → master → producao` +
`deploy.bat` (com ordem explícita).
