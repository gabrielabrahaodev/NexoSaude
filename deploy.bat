@echo off
echo --- 0. CARIMBANDO VERSAO DO PWA ---
powershell -ExecutionPolicy Bypass -File tool\bump_version.ps1
if errorlevel 1 (
  echo ERRO: nao foi possivel atualizar a versao do PWA.
  exit /b 1
)
echo --- 1. LIMPANDO E GERANDO BUILD ---
if "%PRIVATE_FILES_API_URL%"=="" (
  echo ERRO: configure PRIVATE_FILES_API_URL com a URL HTTPS base do Worker Cloudflare.
  echo Ele atende documentos privados e pedidos de trial com rate-limit. Deploy cancelado.
  exit /b 1
)
call flutter clean
if errorlevel 1 exit /b 1
call flutter build web --base-href "/sistema-interno/" --dart-define=PRIVATE_FILES_API_URL=%PRIVATE_FILES_API_URL%
if errorlevel 1 exit /b 1
call powershell -NoProfile -ExecutionPolicy Bypass -File tool\write_worker_config.ps1 -OutputPath "build\web\worker-config.js" -WorkerUrl "%PRIVATE_FILES_API_URL%"
if errorlevel 1 exit /b 1

echo --- 2. ORGANIZANDO PASTAS DE SEGURANCA ---
cd /d build\web
if errorlevel 1 (
  echo ERRO: diretorio build\web nao encontrado.
  exit /b 1
)
if not exist sistema-interno mkdir sistema-interno
if errorlevel 1 exit /b 1

:: Primeiro, movemos TUDO (arquivos soltos) para a pasta segura
move *.* sistema-interno
if errorlevel 1 (
  echo ERRO: falha ao organizar arquivos do build.
  exit /b 1
)

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
if exist sistema-interno\logo.png move sistema-interno\logo.png .
if exist sistema-interno\worker-config.js move sistema-interno\worker-config.js .
if exist sistema-interno\master.html move sistema-interno\master.html

:: LANDING NA RAIZ: vira o index.html de nexosaude.web.app/
:: (portal.html e demais páginas públicas PERMANECEM em /sistema-interno/)
if exist sistema-interno\landing.html move sistema-interno\landing.html index.html
:: (portal.html já nasce em build\web\ via web\ — move junto p/ dentro:)
if exist portal.html move portal.html sistema-interno

echo --- 3. ENVIANDO PARA O FIREBASE (projeto nexosaude) ---
:: Voltamos para a raiz do projeto para rodar o deploy
cd /d ..\..
if errorlevel 1 (
  echo ERRO: nao foi possivel retornar a raiz do projeto.
  exit /b 1
)
call firebase deploy --only hosting --project=nexosaude
if errorlevel 1 (
  echo ERRO: o deploy do Firebase Hosting falhou. Verifique a saida acima.
  exit /b 1
)

echo --- SUCESSO! SITE ATUALIZADO ---
pause
