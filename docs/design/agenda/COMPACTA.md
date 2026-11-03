# Agenda compacta — 03/11/2026

Pedido: priorizar redução dos cabeçalhos e reduzir menos as linhas, exibindo até 15h na janela de aproximadamente 1534×727.

Barra com padding vertical de 4px, margem superior de 4px e separação de 6px; seletor profissional denso. Cabeçalho da grade passa de 76 para 44px e marcador do dia de 32 para 24px. As linhas usam altura adaptativa de 36 a 44px, calculada para 14 intervalos de meia hora (08:30–15:00); horários posteriores continuam roláveis. Cartões acompanham a altura real, com duas linhas compactas e tooltip de detalhes, sem altura mínima antiga de 48px que invadiria o slot seguinte. Posicionamento/duração e faixas de encaixe continuam proporcionais.

Teste de geometria acrescentado nos dois temas com reserva de 64px para shell e 286px para sidebar. Execução Flutter/renderização pendente por ausência do SDK no ambiente. Diff --check aprovado; nenhum deploy realizado. Em telas muito baixas, zoom/texto ampliado ou consultas anteriores às 08:30 a rolagem permanece necessária.
