---
title: Clinic Lab
tags: [nexosaude, brain, screens]
name: screen-clinic-lab
description: Kanbans de laboratório geral/individual e criação independente de contas a pagar.
---

# Laboratório — PR #2

## Telas e referência visual

`ClinicLabScreen` (menu) e `PatientLabTab` (ficha) usam `LabKanbanBoard` + `ClinicalLabView`: título com quantidade real de ordens ativas, Exportar CSV, Novo Pedido, busca e filtros por laboratório, solicitante e tipo. Quatro colunas com cabeçalhos pastel, contagem, cartões com faixa de cor, identificação, descrição, custo, profissional, laboratório, prazo e interação. Os dois temas são respeitados; em telas pequenas, página e colunas podem rolar. Menu, logo original e preferência de tema permanecem os já existentes.

`Solicitado/pending_send` → Aguardando Envio; `sent/Enviado` → Enviado; `pending_return` → Aguardando Retorno; `delivered/Concluído/Entregue` → Entregue. Status desconhecidos permanecem visíveis na primeira coluna e o valor bruto aparece nos detalhes. Arrastar ou menu Mover pede data antes de gravar. Detalhes, histórico, nova interação e exclusão permanecem disponíveis.

## Criar pedido

Os dois botões usam `showLabOrderDialog`/`LabOrderDialog`. Na ficha, paciente já vem fixo; no geral, é selecionado. Catálogos e tratamentos são lidos apenas na clínica atual. Selecionar fornecedor da categoria Laboratório, informar descrição, solicitante/tratamento/tipo opcionais e previsão. A resposta a “Houve custo?” é obrigatória.

- Não: cria pedido sem despesa.
- Sim: exige valor positivo em BRL e vencimento; cria conta `expenses` com `status: pendente`, categoria Laboratório, paciente, fornecedor e tratamento opcional. Não marca pagamento nem cria receita em `financial`.
- A conta fica em **Relatórios → A Pagar**, no mês de vencimento. No fluxo financeiro projetado é uma saída; só entra como paga após a baixa em A Pagar.

## Atomicidade e autorização

`LabService.createOrder` grava pedido + despesa (se houver) + comprovante de criação numa transação. ID estável por abertura e despesa `lab_<pedidoId>` impedem duplicação em reenvios/retries. O comprovante fica em `patients/<paciente>/clinical_data/lab_request_<pedidoId>`: as Rules atuais permitem ler esse documento ainda inexistente pelo escopo do paciente. Não se lê um `lab_orders` inexistente, o que seria negado pelas Rules atuais. Reenvio idêntico não recria a despesa nem desfaz uma baixa; payload diferente é recusado.

Paciente, laboratório e tratamento são conferidos na clínica e o plano deve pertencer ao paciente. Troca de unidade impede concluir o contexto antigo. Não há mudança nem publicação de Rules. A cascata existente de `clinical_data` já limpa os comprovantes na exclusão do paciente.

## Independência financeira e legado

Receber pagamento não cria laboratório. Estorno/cancelamento não exclui pedidos; despesas `source: lab_order` também são preservadas. Excluir pedido pelo kanban mantém eventual conta a pagar e avisa isso na confirmação: gerenciar a obrigação pelo financeiro.

Novos campos: `hasCost`, `costDueDate`, `relatedExpenseId`, `workType`; despesa possui `source: lab_order` e `relatedLabOrderId`. `relatedFinancialId` legado continua legível, mas novos pedidos/custos não são vinculados ao recebimento. Pedidos antigos não são migrados nem geram despesas retroativas automaticamente, evitando duplicação.

## Diferenças de dados da imagem

Não existe numeração sequencial de OS: o cartão mostra o ID real do pedido. Não há flag de urgência nem horário de previsão; atraso é calculado pela data registrada, sem inferir urgência. Tipos novos são opcionais; dados antigos ausentes aparecem como Não informado. Comunicação usa o histórico manual de interações, sem integração externa automática. A busca global e o sino da imagem não foram inventados no cabeçalho compartilhado; busca/filtros locais e exportação CSV funcionam.

## Validação

Ver `docs/design/lab/TESTE.md`, `lab_service_test.dart`, `financial_lab_independence_test.dart`, `clinical_lab_view_test.dart`, `lab_order_dialog_test.dart` e as regressões de laboratório em `test/rules/matrix.test.js`.
