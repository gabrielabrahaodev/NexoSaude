@echo off
echo --- 1. LIMPANDO E GERANDO BUILD ---
call flutter clean
call flutter build web --base-href "/sistema-interno/"

echo --- 2. ORGANIZANDO PASTAS DE SEGURANCA ---
cd build\web
if not exist sistema-interno mkdir sistema-interno

:: Primeiro, movemos TUDO (arquivos soltos) para a pasta segura
move *.* sistema-interno

:: Movemos as pastas de recursos (o move *.* nao move pastas automaticamente)
:: (só se existirem — nomes mudam entre versões do Flutter)
if exist assets move assets sistema-interno
if exist icons move icons sistema-interno
if exist canvaskit move canvaskit sistema-interno
if exist flutter_service_worker.js move flutter_service_worker.js sistema-interno
if exist flutter.js move flutter.js sistema-interno
if exist manifest.json move manifest.json sistema-interno
if exist version.json move version.json sistema-interno

:: AGORA O PULO DO GATO:
:: O confirmar.html tambem foi movido para dentro. Vamos busca-lo de volta para a raiz.
if exist sistema-interno\confirmar.html move sistema-interno\confirmar.html .
if exist sistema-interno\anamnese.html move sistema-interno\anamnese.html .

echo --- 3. ENVIANDO PARA O FIREBASE (projeto nexosaude) ---
:: Voltamos para a raiz do projeto para rodar o deploy
cd ..\..
call firebase deploy --only hosting --project=nexosaude

echo --- SUCESSO! SITE ATUALIZADO ---
pause