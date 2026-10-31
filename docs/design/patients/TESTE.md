# Ficha do paciente — avaliação na PR #2

Referências recebidas em 30/10/2026: `screen.png`, `code(3).html` e `DESIGN.md`.

## Abrir

Na branch `feat/agenda-clinical-dark`, executar `flutter pub get` e `flutter run -d chrome`. Abrir **Pacientes** e selecionar um cadastro. Em odontologia, a abertura padrão mostra **Odontograma** somente com o mapa dental. Links de Agenda/Atendimento continuam abrindo a aba solicitada. Psicologia mantém suas seis abas.

## Conferir com contas de teste

1. Conferir menu/unidade e `logo.png` original. Nome, situação, contato, CPF mascarado, ID e consentimento devem refletir o cadastro real. O selo LGPD aparece somente quando há aceite registrado.
2. Conferir os quatro indicadores. Valores dependem dos registros da clínica; dados ilustrativos e percentuais da imagem não são inseridos. Falha ou carregamento dos indicadores não deve ser apresentado como saldo confirmado.
3. Clicar nas nove abas odontológicas ou seis de psicologia. Conferir edição do cadastro, anamnese, documentos, prontuário, laboratório e orçamentos existentes. Alternar unidade ou menu deve retirar a ficha anterior da área visível.
4. Conferir o odontograma já salvo. Alterar uma face, salvar e reabrir. Testar raiz com pressão prolongada, endodontia, implante, coroa e suas restrições. Testar zoom +/−, ajuste à tela e arrastar. No celular o mapa começa em escala legível e permite arrastar até os demais dentes. Uma falha de leitura deve mostrar erro, não um mapa saudável editável.
5. Tratamentos: conferir valores, parcelas, margem e diálogo financeiro. Receber parcela leva à seleção de cobranças reais em Pagamentos. Novo tratamento abre Orçamentos, mantendo o fluxo de aprovação existente. Encerrar exige confirmação e usa o serviço atual.
6. Cobranças: testar filtro de valor/procedimento e ordenação. Livro caixa e cobranças devem aparecer apenas em Pagamentos. No desktop há tabela; no mobile, lista. Receber uma cobrança avulsa abre o diálogo existente; cobranças parceladas continuam no modal da família. Conferir pagamentos parciais, parcelas, cancelados, substituídos, estorno e correção. Novo recebimento seleciona um lançamento em aberto, sem criar cobrança arbitrária. Custos e repasses permanecem abaixo da tabela.
7. Atualizar resumo clínico e conferir alertas reais. A atualização usa o resumo já existente no sistema, sem enviar dados para um serviço de IA externo.

## Verificação automatizada

`test/clinical_patient_view_test.dart` cobre larguras 320/390/768/1024/1440, identidade/CPF/consentimento, callbacks financeiros e de tratamento, faces/raiz do odontograma, zoom e salvar. Prévia interna renderizada em 390 e 1000px para comparação visual. Testes visuais usam dados controlados e não substituem a validação autenticada.

A flag `--dart-define=AGENDA_CLINICAL_DARK=false` mantém a ficha anterior para comparação. Sem alteração de Rules, dependências ou deploy.


## Correção das referências de Cadastro e Tratamentos

- Odontograma não pode exibir o título Planos de Tratamento nem Livro Caixa. Conferir essas seções apenas em Tratamentos e Pagamentos, respectivamente.
- Em Tratamentos, conferir título e botão Novo Tratamento, margem, valores alinhados à direita, progresso, Receber Parcela, Ver Dentes Vinculados e encerramento com confirmação. Conferir plano sem dentes associados: não devem aparecer vínculos inventados.
- Cadastro: comparar os cinco cartões e suas duas colunas com `image(1).png`; editar e salvar todos os campos novos, cancelar e reabrir. Conferir paciente legado com endereço String e Map, sem perda de dados. Conferir telefone/CPF/data, CEP válido/ausente/falha de rede, resposta atrasada após cancelar e dados de emergência/preferências.
- Consentimento e controles do portal continuam separados da gravação do cadastro. O PDF depende de documento registrado.
- Testes adicionais em `patient_registration_test.dart` e `clinical_registration_view_test.dart` cobrem preservação de mapas, patch limitado ao cadastro, CPF, vínculos dentários explícitos e formulário em 320/390/600/1000/1440px.

Validação da correção: 266 testes Flutter aprovados; análise estática sem erros; build Web release concluído. Prévia de Cadastro em 600px e de Tratamentos em 900px renderizada e conferida com as imagens enviadas, além dos testes de formulário em larguras de 320 a 1440px.
