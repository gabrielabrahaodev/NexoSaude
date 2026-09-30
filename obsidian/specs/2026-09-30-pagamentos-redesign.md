---
title: Redesign da aba Pagamentos
type: spec
status: draft
updated: 2026-09-30
tags: [spec, pagamentos, patient-tab, redesign, financeiro]
---

# Redesign da aba Pagamentos

## Contexto

A aba PAGAMENTOS da tela de detalhes do paciente (`lib/screens/patients/tabs/patient_financial_tab.dart`, resumo em `lib/screens/patients/patient_details_screen.dart`) é onde recepcionista, profissional e owner veem quanto o paciente deve (A RECEBER), quanto já entrou (RECEBIDO) e a timeline de lançamentos com cobrança via WhatsApp. O modelo já existe e é estável: `FinancialModel` (`lib/models/financial_model.dart`) com `amount`, `dueDate`, `isPaid` (getter derivado de `status`+`paidAmount`), `parentId` (família de parcelamento), `paymentMethod` e `installmentNumber`.

Duas análises cruzadas do screenshot de 30/09/2026 mostraram que a aba responde "quanto deve?" em 5 segundos, mas mente por omissão: vencidos sem flag, chip que esconde estado de pagamento, totais sem lastro e moeda em formato estrangeiro. Como tudo é leitura de campos existentes + cálculo no client, o redesign cabe no plano Spark sem backend novo — por isso foi escolhido agora, antes de qualquer feature financeira nova.

## Problema

- **P0 — a aba mente sobre dinheiro:** PAG-01 (vencidos de 19/09 e 24/09 sem flag em 30/09), PAG-02 (chip `PARCELADO` esconde se está pago/pendente/vencido), PAG-03 (A RECEBER R$ 3.650 sem contagem de lançamentos), PAG-04 (`formatBRL` em `lib/utils/display.dart:30` gera `R$ 3650.00`), PAG-17 (resumo em `patient_details_screen.dart:177-186` soma pai substituído + filhas → conta dobrada).
- **P1 — cobrança e leitura:** PAG-05 (`patient_smart_context_card.dart:66` diz "ontem" sem data absoluta), PAG-06 (WhatsApp só com `tooltip`, sem rótulo visível — o diálogo de confirmação pós-envio já existe), PAG-07 (verde = risco clínico e dinheiro entrado na mesma linha), PAG-08 (`CUSTO OPERACIONAL R$ 0,00` em âmbar), PAG-09 (ASSIDUIDADE em 1º numa aba financeira), PAG-10 ("Sessão 1" triplicada — origem a investigar), PAG-18 (nó da timeline usa `status == 'pending'` cru em `patient_financial_tab.dart:2084` e discorda do chip em casos de cartão e `pendente` minúsculo).
- **P2 — polimento:** PAG-11 (nós sem legenda), PAG-12 (metade direita vazia no desktop), PAG-13 (agrupamento por plano só no modal, sem progresso inline), PAG-14 (contraste fraco em datas/subtítulos), PAG-15 (cor como único indicador de estado).

## Decisão

- Chip de linha mostra **sempre estado de pagamento** (`PAGO` / `A VENCER` / `VENCIDO há N dias` / `CANCELADA`); estrutura (`Parcelado`, `Avulso`) vira subtítulo + link para a família (`parentId`, modal `_showFamilyModal` já existe).
- Totais do resumo ganham lastro: `(N lançamentos)` sob cada card + `próximo vencimento: dd/MM • R$ X` sob A RECEBER; resumo passa a usar `visibleCharges` e a excluir substituídos (elimina a conta dobrada).
- `formatBRL` passa a `NumberFormat.currency(locale: 'pt_BR', symbol: 'R$')` (precedente: `lib/services/whatsapp_helper.dart:9` já usa); teste `test/display_helpers_test.dart` atualizado junto.
- Semântica de cor documentada aqui (não existe `decisions/` nem `_templates/adr.md` no vault — ver Rastreio):

| Onde | Valor | Cor | Por quê |
|---|---|---|---|
| Linha | PAGO | verde | dinheiro entrado / estado final bom |
| Linha | A VENCER | azul-acinzentado | neutro, sem alarme |
| Linha | VENCIDO há N dias | vermelho | único alarme da linha |
| Linha | Parcelado (pai substituído) | blueGrey (mantido) | é histórico, não dívida ativa |
| Linha | Cancelada | cinza (mantido) | fora de cobrança/relatórios |
| Resumo | A RECEBER | âmbar (mantido) | atenção, não erro |
| Resumo | RECEBIDO | verde (mantido) | ok, mesma família do PAGO |
| Resumo | CUSTO OPERACIONAL | neutro; âmbar só se > 0 | zero não é alerta |
| Resumo | ASSIDUIDADE | escala de risco + ícone + texto | verde aqui = risco, distinto do financeiro pelo ícone |

- O que **não** muda: card roxo RESUMO DE CONTEXTO (só ganha data absoluta), timeline vertical com nós (ganha legenda + glifos, mantém diferencial), 4 cards no topo (reordenados por papel, não removidos), chip por linha (separado por dimensão, não removido).

## Alternativas descartadas

- **Remover a timeline e virar tabela:** descartado — a timeline com nós é diferencial do produto e o modal de família já depende dela.
- **Novo campo `isOverdue` no Firestore + backfill:** descartado — vencido é função pura de `dueDate`/`hoje`; gravar derivável gastaria cota de escrita no Spark à toa.
- **Reordenação fixa única dos cards:** descartado em favor de ordem por papel (PAG-09) — recepcionista vive de A RECEBER, owner pode preferir risco primeiro.
- **Reescrever `formatBRL` com formatação manual:** descartado — `intl` já é dependência e `whatsapp_helper.dart` prova o padrão pt-BR no repo.

## Impacto

- **Usuário (recepcionista):** sabe o que está vencido há quantos dias, vê o próximo vencimento sem rolar, e o botão de cobrança passa a ter rótulo (fim do toque acidental mudo).
- **Usuário (owner):** totais reconciliáveis (contagem + sem conta dobrada) e moeda legível em pt-BR nos 4 cards.
- **Paciente:** nenhuma mudança visível (aba é interna); cobrança via WhatsApp chega com o mesmo texto, só que enviada com confirmação consciente.
- **Cota Firestore:** nenhum impacto — zero campo novo, zero query nova (tudo é cálculo sobre streams já assinados: `getByPatientId`, `expenses` por `relatedPatientId`).

## Critérios de aceite

- [ ] Todos os itens P0 resolvidos
- [ ] Todos os itens P1 resolvidos ou justificados
- [ ] Nenhum item novo de dependência de backend introduzido
- [ ] `flutter analyze` limpo
- [ ] Testes de widget cobrindo estado VENCIDO e formatação pt-BR

## Rastreio

- Backlog: [[tasks/backlog-pagamentos]]
- Sprints: [[tasks/sprints-pagamentos]]
- ADRs relacionados: sem `decisions/` nem `_templates/adr.md` no vault em 30/09/2026 — a semântica de cor está documentada na tabela em Decisão acima; criar o ADR quando o template existir.

## Ver também

- [[screens/patient-tabs]]
- [[screens/patient-details]]
- [[modules/financial]]
- [[modules/clinical]]
