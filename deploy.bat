@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Sempre executar a partir da pasta deste BAT, inclusive ao abrir pelo Explorer.
pushd "%~dp0"
if errorlevel 1 goto :directory_error
call :deploy
set "DEPLOY_EXIT_CODE=%ERRORLEVEL%"
popd
goto :finish

:directory_error
echo ERRO: nao foi possivel abrir a pasta do projeto.
set "DEPLOY_EXIT_CODE=1"

:finish
if not "%DEPLOY_EXIT_CODE%"=="0" echo ERRO: deploy interrompido. Codigo de saida: %DEPLOY_EXIT_CODE%. Verifique a mensagem acima.
rem Use --no-pause somente para automacao que ja captura a saida.
if /I not "%~1"=="--no-pause" pause
exit /b %DEPLOY_EXIT_CODE%

:deploy
echo --- VERIFICANDO REQUISITOS ---
where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERRO: PowerShell nao encontrado no PATH.
  exit /b 1
)
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERRO: Flutter nao encontrado no PATH. Verifique a instalacao do Flutter.
  exit /b 1
)
where firebase >nul 2>nul
if errorlevel 1 (
  echo ERRO: Firebase CLI nao encontrado no PATH. Instale com npm install -g firebase-tools.
  exit /b 1
)
rem Integracao R2/Worker adormecida por padrao; ativacao futura e explicita.
set "DEPLOY_WORKER_URL="
if /I "%NEXO_ENABLE_PRIVATE_STORAGE%"=="true" (
  if not defined PRIVATE_FILES_API_URL (
    echo ERRO: integracao privada ativada sem PRIVATE_FILES_API_URL.
    exit /b 1
  )
  set "DEPLOY_WORKER_URL=%PRIVATE_FILES_API_URL%"
) else (
  echo INFO: integracao R2/Worker desativada. Deploy segue normalmente.
)
echo --- 0. CARIMBANDO VERSAO DO PWA ---
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\bump_version.ps1"
if errorlevel 1 (
  echo ERRO: nao foi possivel atualizar a versao do PWA.
  exit /b 1
)
echo --- 1. LIMPANDO E GERANDO BUILD ---
call flutter clean
if errorlevel 1 exit /b 1
call flutter build web --base-href "/sistema-interno/" "--dart-define=PRIVATE_FILES_API_URL=%DEPLOY_WORKER_URL%"
if errorlevel 1 exit /b 1
if defined DEPLOY_WORKER_URL (
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\write_worker_config.ps1 -OutputPath "build\web\worker-config.js" -WorkerUrl "%DEPLOY_WORKER_URL%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\write_worker_config.ps1 -OutputPath "build\web\worker-config.js" -Disabled
)
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
if exist sistema-interno\assinatura.html move sistema-interno\assinatura.html .
if exist sistema-interno\worker-config.js move sistema-interno\worker-config.js .
if exist sistema-interno\master.html move sistema-interno\master.html .

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
exit /b 0
