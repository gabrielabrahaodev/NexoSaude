---
title: Sprints — Redesign da aba Pagamentos
type: spec
status: draft
updated: 2026-09-30
tags: [sprints, pagamentos, planning]
---

# Sprints — Redesign da aba Pagamentos

Derivado do backlog [[tasks/backlog-pagamentos]].
Todos os IDs abaixo existem no backlog — nenhum ID inventado.

## Premissas

- **Duração da sprint:** 1 semana
- **Capacidade:** 1 dev full-time (você + agente)
- **Cadência de release:** fim de cada sprint

## Sprint 1 — Correções críticas

**Objetivo:** a aba não mente mais sobre vencidos, valores e totais.
**Duração:** 1 semana.
**Esforço total:** 4S + 1M.

### Itens

- [ ] PAG-01 — Estado VENCIDO há N dias (S)
- [ ] PAG-02 — Chip só estado; parcelamento em subtítulo (M)
- [ ] PAG-03 — Contagem nos totais + próximo vencimento (S)
- [ ] PAG-04 — Formato de moeda pt-BR (S)
- [ ] PAG-17 — Resumo sem conta dobrada (S)

### Entrega esperada

A recepcionista abre a aba e vê de cara o que está vencido há quantos dias, com valores em `R$ 3.650,00` e totais que batem com a lista. O chip de cada linha diz o estado real de pagamento, e o parcelamento aparece como informação, não como estado.

### Riscos

- PAG-02 muda o card mais tocado da aba → mitigação: screenshot antes/depois obrigatório + teste de widget nos 3 ramos de status.
- PAG-04 pode quebrar goldens que esperam `R$ 3650.00` → mitigação: rodar a suite completa após a troca e atualizar expectativas no mesmo commit.

---

## Sprint 2 — Refinamentos

**Objetivo:** cobrar com confiança e ler sem ambiguidade.
**Duração:** 1 semana.
**Esforço total:** 6S.

### Itens

- [ ] PAG-05 — Data absoluta ao lado de "ontem" (S)
- [ ] PAG-06 — WhatsApp com rótulo "Cobrar" + confirmação (S)
- [ ] PAG-07 — Cores semânticas distintas (S)
- [ ] PAG-08 — Zero em cor neutra (S)
- [ ] PAG-09 — Reordenar cards por papel (S)
- [ ] PAG-18 — Nó da timeline usa mesma regra do chip (S)

### Entrega esperada

O botão de cobrança tem nome e tamanho de gente grande, o "ontem" do contexto vem com data auditável, cada papel vê os cards na ordem do seu trabalho, e o nó da timeline nunca mais discorda do chip (fim do "chip verde, nó vermelho" no cartão).

### Riscos

- PAG-09 depende da fonte de papel estar acessível no widget → mitigação: fallback com A RECEBER primeiro para todos, documentado no PR.
- PAG-07 mexe em tokens usados por outras telas → mitigação: escopo restrito aos 2 arquivos do backlog; nada global.

---

## Sprint 3 — Polimento

**Objetivo:** investigar a origem do "Sessão 1" e fechar acessibilidade e layout.
**Duração:** 1 semana.
**Esforço total:** 3S + 3M.

### Itens

- [ ] PAG-10 — Investigar "Sessão 1" triplicada (M)
- [ ] PAG-11 — Legenda dos nós (S)
- [ ] PAG-12 — Uso da área direita no desktop (M)
- [ ] PAG-13 — Agrupamento por plano (M)
- [ ] PAG-14 — Contraste e alvos de toque (S)
- [ ] PAG-15 — Glifos distintos por estado (S)

### Entrega esperada

A causa do "Sessão 1" está documentada e corrigida na origem, o desktop usa a largura toda, cada estado tem cor + texto + ícone (legível para daltônicos), e a legenda dos nós elimina a última adivinhação da timeline.

### Riscos

- PAG-10 pode revelar bug de escrita maior que o previsto → mitigação: timebox de 1 dia para a investigação; se estourar, correção vai para "Backlog não alocado" com a causa documentada.
- PAG-12 responsivo pode divergir entre larguras → mitigação: screenshots em 360px, 768px e 1280px no PR.

---

## Backlog não alocado

Nenhum — todos os PAG-01 a PAG-18 estão alocados (P3 não se aplica; só planejar 3 sprints).

## Rastreio

- Spec: [[specs/2026-09-30-pagamentos-redesign]]
- Backlog: [[tasks/backlog-pagamentos]]
- Kanban Operon: não existe `obsidian/tasks/kanban.md` em 30/09/2026 — o board canônico é `[[Sprint - Backlog]]` (ver `[[00-index]]` §Gestão); ao criar cards Operon para PAG-XX, referenciar este arquivo como fonte.
