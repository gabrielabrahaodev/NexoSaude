param(
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$WorkerUrl
)

$ErrorActionPreference = 'Stop'
try {
    $uri = [System.Uri]::new($WorkerUrl.Trim())
} catch {
    throw 'PRIVATE_FILES_API_URL deve ser uma URL HTTPS válida do Worker.'
}
if ($uri.Scheme -ne 'https' -or
    [string]::IsNullOrWhiteSpace($uri.Host) -or
    $uri.AbsolutePath -ne '/' -or
    -not [string]::IsNullOrEmpty($uri.Query) -or
    -not [string]::IsNullOrEmpty($uri.Fragment) -or
    -not [string]::IsNullOrEmpty($uri.UserInfo)) {
    throw 'PRIVATE_FILES_API_URL deve conter somente a origem HTTPS do Worker, sem caminho, credenciais, query ou fragmento.'
}

$origin = $uri.GetLeftPart([System.UriPartial]::Authority)
$json = ConvertTo-Json -InputObject $origin -Compress
$content = "window.NEXO_WORKER_URL = $json;" + [Environment]::NewLine
$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    throw "Diretório de build não encontrado: $parent"
}
[System.IO.File]::WriteAllText(
    $OutputPath,
    $content,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Output 'Configuração pública do Worker gerada no diretório de build.'
