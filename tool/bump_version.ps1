# Gera web/version.json com carimbo do deploy.
# Rodar ANTES de `flutter build web` (o build copia web/ -> build/web).
# Uso: powershell -File tool/bump_version.ps1
$v = Get-Date -Format 'yyyyMMdd-HHmm'
Set-Content -LiteralPath 'web/version.json' -Value ('{"version": "' + $v + '"}') -Encoding UTF8 -NoNewline
Write-Output ('version.json -> ' + $v)
