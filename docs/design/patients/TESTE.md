# Ficha do paciente — avaliação na PR #2

Referências recebidas em 30/10/2026: `screen.png`, `code(3).html` e `DESIGN.md`.

## Abrir

Na branch `feat/agenda-clinical-dark`, executar `flutter pub get` e `flutter run -d chrome`. Abrir **Pacientes** e selecionar um cadastro. Em odontologia, a abertura padrão mostra **Odontograma** com tratamentos e cobranças abaixo, como na referência. Links de Agenda/Atendimento continuam abrindo a aba solicitada. Psicologia mantém suas seis abas.

## Conferir com contas de teste

1. Conferir menu/unidade e `logo.png` original. Nome, situação, contato, CPF mascarado, ID e consentimento devem refletir o cadastro real. O selo LGPD aparece somente quando há aceite registrado.
2. Conferir os quatro indicadores. Valores dependem dos registros da clínica; dados ilustrativos e percentuais da imagem não são inseridos. Falha ou carregamento dos indicadores não deve ser apresentado como saldo confirmado.
3. Clicar nas nove abas odontológicas ou seis de psicologia. Conferir edição do cadastro, anamnese, documentos, prontuário, laboratório e orçamentos existentes. Alternar unidade ou menu deve retirar a ficha anterior da área visível.
4. Conferir o odontograma já salvo. Alterar uma face, salvar e reabrir. Testar raiz com pressão prolongada, endodontia, implante, coroa e suas restrições. Testar zoom +/−, ajuste à tela e arrastar. No celular o mapa começa em escala legível e permite arrastar até os demais dentes. Uma falha de leitura deve mostrar erro, não um mapa saudável editável.
5. Tratamentos: conferir valores, parcelas, margem e diálogo financeiro. Receber parcela leva à seleção de cobranças reais em Pagamentos. Novo tratamento abre Orçamentos, mantendo o fluxo de aprovação existente. Encerrar exige confirmação e usa o serviço atual.
6. Cobranças: testar filtro de valor/procedimento e ordenação. No desktop há tabela; no mobile, lista. Receber uma cobrança avulsa abre o diálogo existente; cobranças parceladas continuam no modal da família. Conferir pagamentos parciais, parcelas, cancelados, substituídos, estorno e correção. Novo recebimento seleciona um lançamento em aberto, sem criar cobrança arbitrária. Custos e repasses permanecem abaixo da tabela.
7. Atualizar resumo clínico e conferir alertas reais. A atualização usa o resumo já existente no sistema, sem enviar dados para um serviço de IA externo.

## Verificação automatizada

`test/clinical_patient_view_test.dart` cobre larguras 320/390/768/1024/1440, identidade/CPF/consentimento, callbacks financeiros e de tratamento, faces/raiz do odontograma, zoom e salvar. Prévia interna renderizada em 390 e 1000px para comparação visual. Testes visuais usam dados controlados e não substituem a validação autenticada.

A flag `--dart-define=AGENDA_CLINICAL_DARK=false` mantém a ficha anterior para comparação. Sem alteração de Rules, dependências ou deploy.

Validação desta alteração: 257 testes Flutter aprovados; componentes verificados de 320 a 1440px; prévias em 390/1000px renderizadas e inspecionadas; análise estática sem erros; build Web release concluído. As entradas do cache de compilação foram confrontadas com os 13 arquivos Dart alterados da implementação final.
