# Tags de procedimentos e atendimento

## Modelo adotado
- `procedures/{procedureId}/tags/definition`: definição de catálogo independente, salva no mesmo batch do procedimento em Gestão. Cópia completa de preço, categoria, repasse, custo, mensalidade e demais campos do modelo; sem dados de paciente.
- `patients/{patientId}/procedure_tags/budget_{budgetId}_line_{index}`: uma instância por linha de cada orçamento aprovado. Inclui clínica, paciente, orçamento, plano, índice, procedimento, nome/categoria, valor contratado/quantidade/região em campos diretos para análise, `lineSnapshot` completo (valor contratado, desconto, quantidade, região/dentes) e `definitionSnapshot` do catálogo. IDs determinísticos impedem fusão entre orçamentos ou linhas repetidas. Uma linha com quantidade maior que um representa a conclusão de todas as unidades daquela linha.
- `appointments.procedureTagIds`: Tags selecionadas para a consulta; sem alterar a cobrança.
- `patients/{patientId}/clinical_data/tag_visit_{appointmentId}` e `clinical_records/care_{appointmentId}`: histórico de Tags efetivamente atendidas, decisões de conclusão, operador, profissional, data e evolução. Registro por atendimento, sem arrays históricos ilimitados no documento da Tag.

Uma Tag pode passar de pending para in_progress ou completed. Desmarcar na consulta apenas retira o vínculo daquele encontro, preservando o procedimento do paciente. Concluir altera a etapa clínica correspondente no plano, não quita receitas nem encerra automaticamente o plano inteiro. Limite de oito Tags por encontro mantém as leituras transacionais dentro dos limites de Rules/Firestore; nenhuma limitação ao número de Tags de um paciente.

## Fluxos
Gestão salva procedimento + definição juntos. Aprovar orçamento confere paciente/clínica/itens atuais em transação e cria plano, Tags e financeiros juntos; orçamento já aprovado não gera novas cobranças/Tags. Referências de orçamento/plano são reais, sem numeração ilustrativa. Definições futuras não alteram as cópias contratadas existentes.

Formulário odontológico: busca/cadastro do paciente, tabela real de procedimentos, Tags pendentes, calendário mensal amplo, horários reais com carregamento/erro, observações e marca de encaixe/urgência, confirmação fixa no rodapé. Seleção precisa ser contínua e respeita a disponibilidade lida pela agenda existente; não foi criado bloqueio transacional de concorrência de horários. Encaixe continua pelo fluxo que já permite o segundo paciente, não por liberar qualquer slot ocupado.

Ação de agendamento odontológico abre diálogo conforme referência: paciente/status/data, seleção de Tags, conclusão independente por Tag, nota opcional, prontuário, check-in, WhatsApp manual, editar, encaixar, registrar falta/atestado e cancelar. Psicologia mantém o formulário/contrato por presença e atestado existentes. Atendimento também recebe seletor de Tags com rascunho por operador. Finalização valida novamente estado do agendamento, paciente, clínica, Tags e etapas dos planos, gravando tudo em transação. Tag já concluída por outro encontro bloqueia uma revisão desatualizada. Repetir finalização não incrementa sessões novamente.

## Segurança e limites
Aproveita caminhos com Rules já escopadas: subcoleção de procedures com clinicId e subcoleção do paciente autorizada pelo documento pai. Consultas novas filtram clinicId. Não publica/relaxa Rules. Análise futura por clínica inteira requer consulta administrativa ou implementação explícita de relatório/collection-group com Rules/índice próprios; este pacote não cria dashboard analítico.

Não há envio automático de WhatsApp 24h, sala física, especialidade individual ou código de catálogo sequencial no modelo atual; esses exemplos não são inventados. Não há Tags personalizadas sem orçamento: as opções clínicas vêm das linhas aprovadas. Orçamento legado sem vínculo inequívoco de plano fica pendente de revisão na migração. Os históricos anteriores à migração não podem ser reconstruídos; custos/repasses históricos ausentes não são presumidos como os da época.

## Migração
Script: `migrate/backfill-procedure-tags.js`. Exige projeto e clínica explícitos e credencial fora do repositório. Primeiro modo DRY-RUN; grava manifesto antes de qualquer APPLY. Cria somente documentos ausentes, jamais sobrescreve status, sessões ou snapshots. Catálogo é copiado conforme a data da migração, linha contratada vem do orçamento. Procedimento concluído só quando existe status explícito na etapa; plano fechado sem conclusão por etapa vira legacy_closed, sem inventar atendimento. Orçamentos sem plano único ou com linha incompatível são relatados e ignorados. Não modifica planos, financeiros, receitas, despesas, agendamentos ou prontuários antigos. Reexecutar é seguro.

PowerShell na raiz do repositório:
```powershell
npm --prefix migrate ci
node .\migrate\backfill-procedure-tags.js --project nexosaude --clinic "ID_DA_CLINICA" --credential "C:\segredos\nexosaude-admin.json"
# Após conferir o manifesto, executar para a mesma clínica:
node .\migrate\backfill-procedure-tags.js --project nexosaude --clinic "ID_DA_CLINICA" --credential "C:\segredos\nexosaude-admin.json" --apply --confirm "nexosaude:ID_DA_CLINICA"
```
Substituir ID_DA_CLINICA pelo ID Firestore, não pelo nome. Manifestos em tag-migration-backups estão ignorados pelo Git. Guardar cópia local; não compartilhar credencial nem manifesto publicamente.

## Validação
Dois testes Node de migração aprovados; checagem de sintaxe Node e parser Dart aprovados. Testes Flutter para snapshots/serialização/calendário e teste de Rules de isolamento/rollback acrescentados, ainda não executados: SDK Flutter/emulador ausentes no ambiente. Parser não substitui compilação, teste visual nem execução autenticada. Conferir Gestão (novo/editar), aprovação duplicada, dois orçamentos iguais, troca de paciente/unidade, erro de leitura, oito Tags, salvamento de agendamento, conclusão parcial por Tag, remoção de vínculo, falta/atestado e recibos/histórico nos dois temas antes de merge/deploy. Nenhuma migração foi executada nos dados do usuário.

O CI remoto também identificou regressões de layout anteriores a este fluxo: altura fixa dos cards do Dashboard, resumo de vencimento estreito e seletor de modos da Agenda em 320px. Ajustados para altura natural/quebra de linha/encaixe à largura. Teste de busca de Procedimentos agora verifica o Text do resultado, excluindo EditableText do próprio filtro.
