@echo off
echo --- 1. LIMPANDO E GERANDO BUILD ---
call flutter clean
call flutter build web --base-href "/sistema-interno/"

echo --- 2. ORGANIZANDO PASTAS DE SEGURANCA ---
cd build\web
mkdir sistema-interno

:: Primeiro, movemos TUDO (arquivos soltos) para a pasta segura
move *.* sistema-interno

:: Movemos as pastas de recursos (o move *.* nao move pastas automaticamente)
move assets sistema-interno
move icons sistema-interno
move canvaskit sistema-interno
move flutter_service_worker.js sistema-interno
move version.json sistema-interno

:: AGORA O PULO DO GATO:
:: O confirmar.html tambem foi movido para dentro. Vamos busca-lo de volta para a raiz.
move sistema-interno\confirmar.html .
move sistema-interno\anamnese.html .

echo --- 3. ENVIANDO PARA O FIREBASE ---
:: Voltamos para a raiz do projeto para rodar o deploy
cd ..\..
call firebase deploy --only hosting

echo --- SUCESSO! SITE ATUALIZADO ---
pause