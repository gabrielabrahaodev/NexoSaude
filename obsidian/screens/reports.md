---
title: Reports
tags:
  - nexosaude
  - brain
  - screens
name: screen-reports
description: Relatórios gerenciais com KPIs, antecipações e lançamentos manuais.
---

# ReportsScreen

`lib/screens/reports/reports_screen.dart`

## O que é

KPIs (`_KpiCard`), seletor de mês, antecipação de parcelas (`_AnticipationCard`,
`_AnticipationParcel`) e cards expansíveis de despesa; grava `financial`/`expenses`
e lê `clinics/{id}/settings/fees`.

## Quando usar

Fechamento mensal, antecipar recebível, despesa manual.

## Gotchas

- `_endOfMonth` morto; casts e `multiple_underscores` pendentes de limpeza.
- Catch vazio em um bloco — tratar ou logar ao tocar.

## Ver também

- [[reports-oracle]] — DRE/Livro com dedupe
- [[financial-report]] — extrato com taxas e PDF
- [[kpi-dashboard]] — KPIs do dia
- [[expenses]] — despesas manuais

## Remodelagem Clinical Precision — PR #2

- `ClinicalReportsView` é apresentação sem Firebase, adaptativa claro/escuro. Quatro abas locais: DRE Agrupado, Fluxo Real, Contas a Pagar e Recebíveis/Antecipações. Busca e categoria não alteram os totais gerais. Estado de aba/busca permanece na troca de tema/mês.
- Os indicadores e tabelas compartilham `OracleReportService.getMonthOverview` com o Livro Caixa. Consultas mensais limitadas por clínica e data; stream reutilizado até mudar mês/atualizar. Não exibir dados anteriores como mês novo durante espera/erro.
- Contas de laboratório são `expenses` pendentes e participam da projeção; baixa confirmada grava data/status/paidAmount em transação, conferindo clínica, cancelamento e valores atuais. Pagamento do paciente continua sem pedido de laboratório.
- Novo Lançamento cria receita avulsa; cobrança de paciente permanece em Pagamentos. Formulário manual valida BRL, descrição e categoria; ID estável e bloqueio enquanto salva. Gerenciar despesas/recorrências mantém a tela anterior acessível.
- Exportar DRE = CSV do período, incluindo status e bruto/líquido separado. Fluxo Real abre Livro Caixa/PDF com initialMonth. Não há conciliação bancária nem fechamento formal: usar apenas dados registrados.
- Recebíveis futuros usam janela de 12 meses; antecipação mantém simulação/confirmação existentes. Débito, substituído, cancelado e antecipado não elegíveis.
- Roteiro: `docs/design/reports/TESTE.md`. Testes: `clinical_reports_view_test.dart` e `reports_aggregation_test.dart`.

## Receita Saúde — relatório e exportação para o Carnê-Leão

Botão `Receita Saúde` ao lado de Exportar DRE, com o mesmo OutlinedButton/tema. Abre conferência do mês/unidade selecionados, com seleção explícita do profissional prestador (não assumir que o operador é o prestador). CPF do profissional vem de members_private somente para owner/superadmin, ou users próprio quando o UID coincide; demais dados podem ser informados na conferência. Sem profissional vinculado exige identificação manual.

`ReceitaSaudeService` consulta financial da clínica por paymentDate/paidDate/date, limitado ao mês, deduplicando IDs. Usa paymentDate do paciente; não usa vencimento de cartão como pagamento nem paidDate de antecipação quando a data original está ausente. Cancelados/substituídos/saídas/pendentes ficam fora. Filhas quitadas representam parciais; fragmentos de antecipação parcial são reunidos no lançamento de origem para não duplicar o recebimento. Não descontar taxas do valor bruto. Cadastros de pacientes são lidos por ID+clinicId para CPF do beneficiário; nunca copiar esse CPF para pagador sem confirmação explícita por linha.

Conferência permite excluir linhas e preencher CPF/data ausentes; os ajustes são somente do arquivo e não alteram cadastros/financeiro. CSV valida dígitos de CPF, mês, profissional único, ocupação, registro até 15 caracteres, limite de 1.000 linhas e valor. PDF de apoio pode listar pendências. CPF/registro/ocupação da conferência não comprovam registro ativo no conselho.

CSV UTF-8 sem cabeçalho/BOM, 16 campos separados por ponto e vírgula, DD/MM/AAAA, decimal vírgula sem milhares, dedução vazia, PF, indicador S. Arquivo para Escrituração no Carnê-Leão Web; emissão oficial exige autenticação gov.br do profissional/representante. Não existe transmissão, protocolo ou marcação de recibo emitido neste fluxo. Antes de importar, conferir recibos já emitidos, pois repetir a importação pode duplicar lançamentos.

Referências oficiais verificadas em 31/10/2026:
- https://www.gov.br/receitafederal/pt-br/assuntos/meu-imposto-de-renda/pagamento/carne-leao/manual
- https://www.gov.br/receitafederal/pt-br/assuntos/meu-imposto-de-renda/pagamento/carne-leao/manual/formato-arquivo

Arquivos: `receita_saude_report.dart`, `receita_saude_service.dart`, `receita_saude_dialog.dart`, `receita_saude_export.dart`. Roteiro em `docs/design/reports/RECEITA_SAUDE.md`.
