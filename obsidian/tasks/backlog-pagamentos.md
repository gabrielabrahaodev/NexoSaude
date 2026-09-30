---
title: Backlog — Redesign da aba Pagamentos
type: spec
status: draft
updated: 2026-09-30
tags: [backlog, pagamentos, tasks]
---

# Backlog — Redesign da aba Pagamentos

Derivado da spec [[specs/2026-09-30-pagamentos-redesign]].
Um item por linha. IDs rastreáveis (`PAG-XX`) que devem aparecer nas
mensagens de commit. Caminhos validados por leitura em 30/09/2026
(arquivo real: `lib/screens/patients/tabs/patient_financial_tab.dart`,
não `lib/features/...`).

## Legenda

- **Tipo:** bug | feat | refactor | test
- **Estimativa:** S (≤4h) | M (4–16h) | L (16–40h)
- **Prioridade:** P0 | P1 | P2 | P3

## Tabela

| ID | Título | Tipo | Est. | Prioridade | Depende de | Arquivo(s) alvo |
|---|---|---|---|---|---|---|
| PAG-01 | Estado VENCIDO há N dias | feat | S | P0 | — | `patient_financial_tab.dart` |
| PAG-02 | Chip só estado; parcelamento em subtítulo | refactor | M | P0 | PAG-01 | `patient_financial_tab.dart` |
| PAG-03 | Contagem nos totais + próximo vencimento | feat | S | P0 | — | `patient_details_screen.dart` |
| PAG-04 | Formato de moeda pt-BR | bug | S | P0 | — | `utils/display.dart`, `test/display_helpers_test.dart` |
| PAG-17 | Resumo sem conta dobrada (pai + filhas) | bug | S | P0 | — | `patient_details_screen.dart`, `services/financial_service.dart` |
| PAG-05 | Data absoluta ao lado de "ontem" | feat | S | P1 | — | `widgets/patient_smart_context_card.dart` |
| PAG-06 | WhatsApp com rótulo "Cobrar" | feat | S | P1 | — | `patient_financial_tab.dart` |
| PAG-07 | Cores semânticas distintas por dimensão | refactor | S | P1 | PAG-01 | `patient_financial_tab.dart`, `patient_details_screen.dart` |
| PAG-08 | Zero em cor neutra | bug | S | P1 | — | `patient_details_screen.dart` |
| PAG-09 | Reordenar cards por papel | feat | S | P1 | — | `patient_details_screen.dart` |
| PAG-18 | Nó da timeline usa mesma regra do chip | bug | S | P1 | PAG-01 | `patient_financial_tab.dart` |
| PAG-10 | Investigar "Sessão 1" triplicada | test | M | P1 | — | criação de lançamentos + `patient_financial_tab.dart` |
| PAG-11 | Legenda dos nós | feat | S | P2 | PAG-18 | `patient_financial_tab.dart` |
| PAG-12 | Uso da área direita no desktop | feat | M | P2 | — | `patient_financial_tab.dart` |
| PAG-13 | Progresso da família inline | feat | M | P2 | PAG-02 | `patient_financial_tab.dart` |
| PAG-14 | Contraste e alvos de toque | refactor | S | P2 | PAG-06 | `patient_financial_tab.dart` |
| PAG-15 | Glifos distintos por estado | feat | S | P2 | PAG-01 | `patient_financial_tab.dart`, `widgets/status_chip.dart` |

## Detalhe por item

### PAG-01 — Estado VENCIDO há N dias

- **Problema:** lançamento com `dueDate < hoje && !isPaid` aparece como `PENDENTE`, sem destaque de atraso (`_buildTimelineItem`, `patient_financial_tab.dart:999-1007`).
- **Solução:** função pura `paymentStateOf({isPaid, dueDate, hoje})` → `PAGO` / `VENCIDO há N dias` / `A VENCER` (`dueDate == null` ou futuro); chip passa a usá-la.
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Chip mostra "VENCIDO há N dias" quando aplicável
  - [ ] Chip mostra "A VENCER" caso contrário (inclui `dueDate == null`)
  - [ ] Teste cobre borda: `dueDate == hoje`
- **DoD:**
  - [ ] Código + teste passando
  - [ ] Screenshot anexado
  - [ ] `flutter analyze` limpo
  - [ ] Commit com `PAG-01` na mensagem
- **Estimativa:** S — função pura + troca de 1 call site; justificativa: sem query nova, só leitura de campos existentes.
- **Sprint:** 1

### PAG-02 — Chip só estado; parcelamento em subtítulo

- **Problema:** `PARCELADO` (estrutura) e `PENDENTE` (estado) ocupam o mesmo slot; item de 19/09 não revela estado de pagamento.
- **Solução:** chip = só `paymentStateOf` (PAG-01); estrutura vira subtítulo (`Avulso` ou `Plano • parcela X de Y` via `familyOf`) + mantém "N parcelas — toque para ver".
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Nenhum chip exibe `PARCELADO` como estado
  - [ ] Pai substituído mantém identidade estrutural no subtítulo + modal
  - [ ] Teste: item com `parentId` exibe parcela no subtítulo
- **DoD:** (padrão — ver PAG-01)
- **Estimativa:** M — mexe no layout do card + 3 ramos de status + modal; justificativa: maior superfície de regressão visual que PAG-01.
- **Sprint:** 1

### PAG-03 — Contagem nos totais + próximo vencimento

- **Problema:** A RECEBER sem `(N lançamentos)`; sem "próximo vencimento", a recepcionista rola a timeline para saber o que cobrar.
- **Solução:** sob cada card do `_HeaderSummaryRow`, `(N)`; sob A RECEBER, `próximo: dd/MM • R$ X` (menor `dueDate` entre não-pagos não-substituídos).
- **Arquivo:** `lib/screens/patients/patient_details_screen.dart`.
- **Critério de aceite:**
  - [ ] Cada total exibe contagem
  - [ ] Próximo vencimento ignora cancelados/substituídos
  - [ ] Sem lançamentos → texto neutro, sem crash
- **DoD:** (padrão)
- **Estimativa:** S — agregação em memória sobre stream já assinado; justificativa: sem query nova.
- **Sprint:** 1

### PAG-04 — Formato de moeda pt-BR

- **Problema:** `formatBRL` (`lib/utils/display.dart:30`) gera `R$ 3650.00` por decisão antiga documentada no próprio comentário ("sem locale").
- **Solução:** `NumberFormat.currency(locale: 'pt_BR', symbol: 'R$')` (precedente: `lib/services/whatsapp_helper.dart:9`); atualizar expectativas em `test/display_helpers_test.dart`.
- **Arquivo:** `lib/utils/display.dart`, `test/display_helpers_test.dart`.
- **Critério de aceite:**
  - [ ] `formatBRL(3650)` → `R$ 3.650,00`
  - [ ] Teste de helpers atualizado e passando
  - [ ] Nenhum golden/screenshot quebrado sem atualização
- **DoD:** (padrão)
- **Estimativa:** S — choke point único; justificativa: 1 função + 1 teste.
- **Sprint:** 1

### PAG-17 — Resumo sem conta dobrada (pai + filhas) [novo, achado no código]

- **Problema:** `_HeaderSummaryRow` (`patient_details_screen.dart:177-186`) soma **todos** os docs: pai substituído (não-pago) + filhas (não-pagas) entram juntos no A RECEBER. A timeline usa `visibleCharges` (só pai), o resumo não → totais divergem da lista.
- **Solução:** resumo filtra com `FinancialService.visibleCharges` + exclui `isReplaced` do A RECEBER (pai é histórico, dívida real está nas filhas visíveis no modal).
- **Arquivo:** `lib/screens/patients/patient_details_screen.dart`, `lib/services/financial_service.dart` (se precisar de helper).
- **Critério de aceite:**
  - [ ] Paciente com família parcelada: A RECEBER == soma das filhas não-pagas
  - [ ] Teste puro cobre pai substituído + 2 filhas (1 paga, 1 aberta)
- **DoD:** (padrão)
- **Estimativa:** S — filtro sobre lista em memória; justificativa: reutiliza `visibleCharges` existente.
- **Sprint:** 1

### PAG-05 — Data absoluta ao lado de "ontem"

- **Problema:** `patient_smart_context_card.dart:66` usa `daysAgoLabel` ("ontem") sem data → impossível auditar contra a timeline (origem é `clinical_records`, não `financial` — provável não-bug, mas não verificável).
- **Solução:** `"Último atendimento foi ontem, 29/09 (proc)."` via `formatDateShort`.
- **Arquivo:** `lib/widgets/patient_smart_context_card.dart`.
- **Critério de aceite:**
  - [ ] Texto inclui data absoluta `dd/MM`
  - [ ] Sem histórico → mensagem existente mantida
- **DoD:** (padrão)
- **Estimativa:** S — 1 linha + teste; justificativa: sem query nova.
- **Sprint:** 2

### PAG-06 — WhatsApp com rótulo "Cobrar"

- **Problema:** `IconButton` só com `tooltip: "Enviar Lembrete"` (`patient_financial_tab.dart:1133-1139`), alvo mínimo (`padding: zero`, `constraints` vazias). Nota: confirmação pós-envio **já existe** (diálogo "Mensagem enviada?" → registra no prontuário só no SIM) — não reinventar.
- **Solução:** botão rotulado "Cobrar" (ícone + texto), altura ≥ 44px; mantém fluxo de confirmação existente.
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Ação tem rótulo visível em pt-BR
  - [ ] Alvo de toque ≥ 44px
  - [ ] Confirmação e registro no prontuário preservados
- **DoD:** (padrão)
- **Estimativa:** S — troca de widget local; justificativa: fluxo de confirmação reaproveitado.
- **Sprint:** 2

### PAG-07 — Cores semânticas distintas por dimensão

- **Problema:** verde = risco clínico (ASSIDUIDADE) e dinheiro entrado (RECEBIDO) na mesma linha; chip `PENDENTE` vermelho sem texto de apoio.
- **Solução:** aplicar tabela da spec (Decisão): linha `A VENCER` em azul-acinzentado, `VENCIDO` vermelho; ASSIDUIDADE ganha ícone + prefixo de risco para não colidir com o verde financeiro.
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`, `lib/screens/patients/patient_details_screen.dart`.
- **Critério de aceite:**
  - [ ] Nenhum estado distinguível só por cor após PAG-15 (este item prepara a base)
  - [ ] Screenshot antes/depois no PR
- **DoD:** (padrão)
- **Estimativa:** S — troca de tokens em call sites mapeados; justificativa: sem lógica nova.
- **Sprint:** 2

### PAG-08 — Zero em cor neutra

- **Problema:** `CUSTO OPERACIONAL R$ 0,00` em âmbar (`patient_details_screen.dart:230-231`) — zero pintado como alerta.
- **Solução:** `custo == 0` → cor neutra (`textSecondary`); âmbar só se > 0.
- **Arquivo:** `lib/screens/patients/patient_details_screen.dart`.
- **Critério de aceite:**
  - [ ] Zero rende em neutro; valor > 0 mantém âmbar
- **DoD:** (padrão)
- **Estimativa:** S — condicional de 1 linha; justificativa: trivial e isolado.
- **Sprint:** 2

### PAG-09 — Reordenar cards por papel

- **Problema:** ASSIDUIDADE em 1º empurra A RECEBER para a direita; recepcionista prioriza dinheiro, owner pode priorizar risco.
- **Solução:** ordem por papel via fonte de papel existente (`SessionManager`/`MenuAccess`, sem `if (role)` hardcoded no menu — convenção do vault); fallback: A RECEBER primeiro para todos se o papel não estiver acessível no widget.
- **Arquivo:** `lib/screens/patients/patient_details_screen.dart`.
- **Critério de aceite:**
  - [ ] Recepcionista vê A RECEBER em 1º
  - [ ] Demais papéis mantêm ordem atual ou definida na spec
- **DoD:** (padrão)
- **Estimativa:** S — reorder de `Row` + leitura de papel; justificativa: sem widget novo.
- **Sprint:** 2

### PAG-18 — Nó da timeline usa mesma regra do chip [novo, achado no código]

- **Problema:** nó usa `status == 'pending'` cru (`patient_financial_tab.dart:2084-2086`): cartão com chip verde "Pago" (quirk `isCard`, linhas 990-997) ganha nó **vermelho**; `pendente` minúsculo ganha nó **verde** com chip vermelho.
- **Solução:** cor do nó deriva do mesmo `paymentStateOf` do chip (PAG-01): verde=PAGO, vermelho=VENCIDO, azul-acinzentado=A VENCER, blueGrey=substituído, cinza=cancelado, laranja=despesa (mantido).
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Nó e chip nunca discordam (teste parametrizado: pending/pendente/cartão/substituído/cancelado)
- **DoD:** (padrão)
- **Estimativa:** S — mesma função pura de PAG-01 aplicada ao nó; justificativa: sem layout novo.
- **Sprint:** 2

### PAG-10 — Investigar "Sessão 1" triplicada

- **Problema:** três entradas "Sessão 1" com horários distintos — contador não incrementa, três pacotes distintos sem contexto, ou título derivado errado. **Origem desconhecida: investigar, não presumir.**
- **Solução:** rastrear escrita de `title`/`description`/`installmentNumber` na criação (wizard de recebimento, pacotes mensais psico `monthlyPeriod`, orçamentos); corrigir na origem; título da linha deriva de `parentId != null ? 'Pacote' : 'Avulso'`.
- **Arquivo:** criação de lançamentos + `lib/screens/patients/tabs/patient_financial_tab.dart` (exibição).
- **Critério de aceite:**
  - [ ] Causa-raiz documentada no PR (bug de contador vs. dados legítimos)
  - [ ] Correção na origem + teste de regressão
  - [ ] Linha exibe "Sessão N de M" ou equivalente auditável
- **DoD:** (padrão)
- **Estimativa:** M — investigação + correção em escrita; justificativa: envolve fluxo de criação, não só leitura.
- **Sprint:** 3

### PAG-11 — Legenda dos nós

- **Problema:** nó preenchido vs. contornado sem semântica declarada.
- **Solução:** linha de legenda sob a barra de filtros (nó + rótulo textual por estado, pós-PAG-18).
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Cada cor de nó tem rótulo visível
  - [ ] Legenda some quando timeline vazia (estado "Nenhuma movimentação" existente)
- **DoD:** (padrão)
- **Estimativa:** S — widget estático; justificativa: sem lógica.
- **Sprint:** 3

### PAG-12 — Uso da área direita no desktop

- **Problema:** trilho da timeline no centro (`width: 30` em `Row` de 3 colunas, linhas 2062-2103) deixa ~50% da largura vazia no desktop.
- **Solução:** `LayoutBuilder`: largura ≥ 700 → card ocupa largura total com trilho à esquerda; mobile mantém layout atual.
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Desktop: sem área vazia à direita
  - [ ] Mobile (< 700): layout inalterado (screenshot comparativo)
- **DoD:** (padrão)
- **Estimativa:** M — responsivo com 2 breakpoints + validação visual; justificativa: teste de widget + screenshots.
- **Sprint:** 3

### PAG-13 — Progresso da família inline

- **Problema:** agrupamento por plano vive só no modal (`_showFamilyModal` + "N parcelas — toque para ver"); progresso (`familyProgress`) invisível na timeline.
- **Solução:** linha de progresso inline no card do pai (`2/6 pagas` + `LinearProgressIndicator` fino, reaproveitando `familyProgress`).
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Pai com filhas exibe progresso textual + barra
  - [ ] Toque continua abrindo o modal existente
- **DoD:** (padrão)
- **Estimativa:** M — novo bloco visual + estados (0/N, N/N); justificativa: reaproveita helpers, mas exige teste de widget.
- **Sprint:** 3

### PAG-14 — Contraste e alvos de toque

- **Problema:** datas/subtítulos em cinza-médio sobre fundo escuro; alvos pequenos além do WhatsApp.
- **Solução:** secundários em `textSecondary` do tema (ou mais claro); demais alvos interativos ≥ 44px.
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`.
- **Critério de aceite:**
  - [ ] Textos secundários dentro do contraste do tema
  - [ ] Nenhum alvo < 44px na timeline
- **DoD:** (padrão)
- **Estimativa:** S — troca de estilos; justificativa: sem lógica (após PAG-06, sem conflito no botão WhatsApp).
- **Sprint:** 3

### PAG-15 — Glifos distintos por estado

- **Problema:** cor como único indicador (daltônicos não distinguem PENDENTE de normal).
- **Solução:** ícone por estado no `StatusChip` (ex.: ✓ pago, relógio a vencer, ⚠ vencido) + texto já existente.
- **Arquivo:** `lib/screens/patients/tabs/patient_financial_tab.dart`, `lib/widgets/status_chip.dart` (se precisar de slot de ícone).
- **Critério de aceite:**
  - [ ] Cada estado tem glifo + cor + texto (3 canais redundantes)
- **DoD:** (padrão)
- **Estimativa:** S — ícones em mapeamento existente; justificativa: sem lógica nova.
- **Sprint:** 3

## Itens bloqueados

| ID | Motivo | Desbloqueio |
|---|---|---|
| — | Nenhum. Tudo é client-side sobre `amount`, `dueDate`, `isPaid`, `parentId`, `status` existentes; plano Spark respeitado. | — |
