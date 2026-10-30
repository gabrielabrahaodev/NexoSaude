# Atendimento por especialidade — PR #2

A implementação segue a hierarquia, superfícies, cores e lista/ficha das duas referências enviadas em 30/10/2026: `code(1).html`/`DESIGN(1).md` para odontologia e `code(2).html`/`DESIGN(2).md` para psicologia. Usa Flutter, Plus Jakarta Sans incluída nos assets com licença OFL e o `assets/logo.png` existente, sem dependências novas. Dados de exemplo, afirmações de criptografia ponta a ponta, CRP, diagnósticos e salas fictícias não são inseridos.

## Executar

Atualizar a branch `feat/agenda-clinical-dark` e executar `flutter run -d chrome`. O menu global e a agenda alternativa estão habilitados por padrão. O Atendimento novo depende do tipo da clínica, usando os dados e as permissões existentes.

## Roteiro autenticado

1. Conferir logo original, item ativo e unidades autorizadas no menu. Alternar entre unidade dental e psicologia; conferir atualização de consultas, membros e tipo de ficha. Profissional vê somente seus atendimentos; gestão/recepção pode filtrar.
2. Abrir Atendimento em 320/390/768/1024/1440px. Conferir ordem cronológica, filtro de status/profissional, confirmação em massa, nova consulta e horários livres. Desktop mostra ficha ao lado; mobile abre modal com fechamento explícito.
3. Iniciar e pausar consulta; conferir estado também na Agenda. Digitar evolução, selecionar marcadores, aguardar rascunho. Fechar/reabrir, navegar no menu e trocar unidade; conferir preservação individual por operador. Simular falha de conexão: não anunciar sucesso nem descartar alterações silenciosamente.
4. Salvar evolução: verificar prontuário, sem finalizar consulta ou registrar presença. Finalizar: verificar evolução e presença juntas; reabrir em somente leitura. Testar consulta cancelada/modificada em outra aba.
5. Odontologia: conferir alertas disponíveis na anamnese, aba Prontuário correta, recebimento de cobrança existente e retorno de 30/21 dias ou personalizado. Validar intervalo completo ocupado, fechamento da grade e profissional escolhido. Novo lançamento segue em Pagamentos.
6. Psicologia: conferir marcadores, síntese, rascunho explícito, pacote/avulsa e progresso de sessões reais. Abrir contrato/Pagamentos. Pacote mensal preserva faturamento por presença/atestado; não gera cobrança duplicada nem debita créditos inventados. Próxima sessão gerada deve ser reutilizada. Avulsa deve passar pelo formulário que cria sessão e lançamento financeiro.
7. Retorno semanal/quinzenal ou personalizado: conferir disponibilidade, clínica, paciente, profissional e aba correta de prontuário/Pagamentos para cada especialidade.

## Validação local

- Flutter 3.47.9 / Dart 3.13.7: 251 testes aprovados.
- Widgets de Atendimento testados de 320 a 1440px; salvar evolução e finalizar são callbacks separados.
- Emulador Firestore: 34 testes aprovados, incluindo rascunho por clínica, gravação conjunta de evolução/presença e rejeição atômica entre clínicas.
- Build Web release concluído.
- Análise estática: zero erros; 224 avisos/informações no projeto.

Testes usam dados controlados e não substituem a avaliação autenticada com contas de teste. Não houve publicação, merge, alteração de Rules de produção ou mudança de dependências. O faturamento mensal existente não foi remodelado.

## Refinamento visual

Comparar com `screen(2).png` (odontologia) e `screen(3).png` (psicologia): painel odontológico contínuo, seções numeradas, rodapé fixo, cartões independentes de psicologia, marcadores tonais compactos, ações verdes, fonte Plus Jakarta Sans e menu com seleção discreta. Confirmar leitura dos marcadores longos no mobile, acesso ao fechamento e ações de salvar/finalizar, sem perder os filtros ou a confirmação em massa. O rodapé fixo não deve cobrir os campos roláveis.

Após este refinamento: 251 testes Flutter aprovados, quatro prévias renderizadas e inspecionadas (390/1200px, duas especialidades), análise sem erros (224 avisos/informações existentes) e build Web release concluído.
