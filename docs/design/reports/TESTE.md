# Relatórios — validação PR #2

A tela usa Clinical Precision, com os quatro indicadores, previsão, abas e grupos de receitas/despesas da referência. Preserva logo/menu existentes, identidade somente no rodapé e alternância claro/escuro abaixo de Sair.

1. Abrir Relatórios em duas unidades distintas. Conferir nome da unidade, mês, totais e ausência de registros da outra clínica.
2. Comparar DRE e Livro Caixa no mesmo mês: receitas recebidas e despesas pagas, base bruta. Cartão segue vencimento; antecipado segue paidDate; débito/Pix/dinheiro pagos seguem baixa. Cancelados e substituídos não entram.
3. Virar o mês: somente as datas efetivas daquele período entram. O último microssegundo do mês permanece; registros do mês vizinho ficam fora. Durante carregamento/erro os indicadores mostram travessão, sem reaproveitar totais do mês anterior.
4. DRE Agrupado mostra entradas e saídas pagas separadamente, profissional/fornecedor/categoria/forma gravados e líquido somente quando informado. Busca e categoria filtram linhas, sem alterar indicadores/subtotais gerais do período.
5. Fluxo de Caixa Real mostra somente pagos, acumulando a partir de zero no mês. Livro Caixa/PDF abre o relatório existente no mesmo mês; exportação PDF existente é preservada.
6. Contas a Pagar mostra pendências do mês e saldo descontando paidAmount. Criar pedido com custo no Laboratório e conferir fornecedor, descrição, valor e vencimento; não registrar receita do paciente. Baixar pede data e confirmação; atualização transacional confere clínica e valor atual e evita baixa dupla. Após baixa, a despesa aparece nas saídas do mês de pagamento. Gerenciar despesas e recorrências mantém acesso à tela existente.
7. Recebíveis & Antecipações junta pendências mensais e cartões dos próximos 12 meses. Não antecipar débito/cancelado/substituído/antecipado/vencido. A ação abre a simulação existente e exige confirmação antes de gravar. Taxa configurada/fallback existente preservados; não há integração com adquirente/banco.
8. Nova Despesa/Novo Lançamento: testar `1.234,56`, descrição e categoria obrigatórias, vencimento e status pago/pendente. Novo Lançamento é receita avulsa, sem paciente fictício. Para cobrança de paciente, usar Pagamentos na ficha. Se já pago/recebido, data informada também é a baixa. Sem cartão no lançamento avulso para não contornar cálculo/parcelamento do fluxo do paciente.
9. Enquanto salva, bloquear edição, fechar e duplo clique. Falha mantém campos e permite retry com mesmo ID, sem duplicação. Troca de clínica antes da gravação impede o envio.
10. Exportar DRE gera CSV do período, com entradas/saídas pagas e pendentes, status e bruto/líquido separados; aspas/acentos/fórmulas são tratados. A exportação usa todo o período, não somente as linhas filtradas.
11. Testar em 390/768/1200px nos dois temas. Tabelas rolam horizontalmente no celular. Trocar tema com aba e busca ativas deve preservar o estado. Falha em recebíveis futuros deve ser explícita e bloquear simulação pelos indicadores.

## Dados da imagem sem equivalente garantido

Conciliação bancária/horário da última conciliação, fechamento formal ABERTO, saldo bancário inicial, variação comparativa mensal, quantidade de atendimentos ligada a recebimentos, número sequencial de recibo/prontuário, especialidade técnica e comprovantes não são inferidos. Profissional, fornecedor, categoria, forma, parcelas e líquido aparecem quando gravados; ausências mostram Não informado. O resultado é caixa bruto menos despesas pagas, não uma DRE contábil com regime de competência. Projeção = pagos + saldos pendentes do mês, sem saldo inicial.

Nenhuma gravação de dados ilustrativos, migração, deploy de índices/Rules ou publicação em produção integra esta alteração.

## Verificação concluída

397 testes Flutter aprovados na suíte geral; 20 testes novos cobrem agregação, limites mensais, cancelamento de streams, BRL, filtros, ações, responsividade e troca de tema. Análise estática sem erros (avisos/informações existentes permanecem), build Web release aprovado. Prévias renderizadas e inspecionadas nos dois temas. As Rules não foram alteradas.
