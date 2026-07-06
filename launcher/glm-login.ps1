# glm-login.ps1 - o "login" do GLM Harness: obtem, valida e instala a chave
# de API da NVIDIA (.env + config do claude-code-router), reiniciando o router
# se ele ja estiver de pe.
#
# Modos:
#   sem parametros  -> interativo: abre a pagina da chave no navegador, pede a
#                      chave no terminal, valida e grava (wizard do primeiro uso)
#   -ApiKey nvapi-x -> nao-interativo: valida e grava a chave informada
#   -ValidateOnly   -> so valida (a do -ApiKey ou a do .env), nao grava nada
#
# Nota: arquivo em ASCII puro de proposito (PS 5.1 le .ps1 sem BOM como ANSI).

param(
    [string]$ApiKey,
    [switch]$ValidateOnly
)

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$EnvFile = Join-Path $ProjectRoot ".env"
$TemplateFile = Join-Path $ProjectRoot "reference\ccr-config.template.json"
$CcrConfigDir = Join-Path $HOME ".claude-code-router"
$CcrConfigFile = Join-Path $CcrConfigDir "config.json"
$KeysPageUrl = "https://build.nvidia.com/settings/api-keys"
$NvidiaEndpoint = "https://integrate.api.nvidia.com/v1/chat/completions"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-KeyFromEnvFile {
    if (-not (Test-Path $EnvFile)) { return $null }
    foreach ($line in (Get-Content $EnvFile)) {
        if ($line -match '^\s*NVIDIA_API_KEY\s*=\s*(\S+)\s*$') { return $Matches[1] }
    }
    return $null
}

function Test-NvidiaKey([string]$Key) {
    # Retorna: ok | throttled (429 = autenticou, free tier ocupado) | invalid | error <detalhe>
    $body = '{"model":"z-ai/glm-5.2","messages":[{"role":"user","content":"ping"}],"max_tokens":1}'
    try {
        Invoke-RestMethod -Uri $NvidiaEndpoint -Method Post -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $Key" } -Body $body -TimeoutSec 60 | Out-Null
        return "ok"
    } catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -eq 401 -or $status -eq 403) { return "invalid" }
        if ($status -eq 429) { return "throttled" }
        return "error $status $($_.Exception.Message)"
    }
}

# ---- resolve a chave: parametro > .env > wizard interativo -----------------

$Key = $ApiKey
if (-not $Key) { $Key = Get-KeyFromEnvFile }

$Interactive = $false
if (-not $Key) {
    if ($ValidateOnly) {
        Write-Host "[glm] Nenhuma chave para validar (nem -ApiKey, nem .env)." -ForegroundColor Red
        exit 1
    }
    $Interactive = $true
    Write-Host ""
    Write-Host "[glm] Login do GLM Harness - chave de API da NVIDIA (gratuita)" -ForegroundColor Magenta
    Write-Host "[glm] Abrindo a pagina de chaves no navegador (logado, a chave aparece direto;" -ForegroundColor DarkGray
    Write-Host "[glm] sem conta, crie gratis ali mesmo e volte). Se a pagina nao abrir certa," -ForegroundColor DarkGray
    Write-Host "[glm] procure 'API Keys' no menu do perfil em build.nvidia.com" -ForegroundColor DarkGray
    Write-Host "[glm]   $KeysPageUrl" -ForegroundColor Cyan
    try { Start-Process $KeysPageUrl } catch { }
    Write-Host ""
}

while ($true) {
    if (-not $Key) {
        $Key = Read-Host "[glm] Cole sua chave nvapi- aqui (Enter vazio cancela)"
        $Key = "$Key".Trim()
        if (-not $Key) {
            Write-Host "[glm] Login cancelado." -ForegroundColor Yellow
            exit 1
        }
    }
    if ($Key -notlike "nvapi-*") {
        Write-Host "[glm] Isso nao parece uma chave da NVIDIA (comeca com nvapi-)." -ForegroundColor Red
        if (-not $Interactive) { exit 1 }
        $Key = $null
        continue
    }
    Write-Host "[glm] Validando a chave na NVIDIA..." -ForegroundColor DarkGray
    $result = Test-NvidiaKey $Key
    if ($result -eq "ok") {
        Write-Host "[glm] Chave valida." -ForegroundColor Green
        break
    }
    if ($result -eq "throttled") {
        Write-Host "[glm] Chave valida (free tier momentaneamente em rate limit - normal)." -ForegroundColor Green
        break
    }
    if ($result -eq "invalid") {
        Write-Host "[glm] Chave recusada pela NVIDIA (401/403). Confira e tente de novo." -ForegroundColor Red
        if (-not $Interactive) { exit 1 }
        $Key = $null
        continue
    }
    Write-Host "[glm] Nao deu para validar agora ($result)." -ForegroundColor Yellow
    if (-not $Interactive) { exit 1 }
    $answer = Read-Host "[glm] Problema de rede? Usar a chave assim mesmo, sem validar? (s/N)"
    if ($answer -match '^[sS]') { break }
    $Key = $null
}

if ($ValidateOnly) {
    Write-Host "[glm] ValidateOnly: nada foi gravado."
    exit 0
}

# ---- grava .env (preserva outras linhas) -----------------------------------

$envLines = @()
if (Test-Path $EnvFile) { $envLines = @(Get-Content $EnvFile) }
$replaced = $false
for ($i = 0; $i -lt $envLines.Count; $i++) {
    if ($envLines[$i] -match '^\s*NVIDIA_API_KEY\s*=') {
        $envLines[$i] = "NVIDIA_API_KEY=$Key"
        $replaced = $true
    }
}
if (-not $replaced) { $envLines += "NVIDIA_API_KEY=$Key" }
[System.IO.File]::WriteAllLines($EnvFile, [string[]]$envLines, $Utf8NoBom)
Write-Host "[glm] Chave gravada no .env" -ForegroundColor DarkGray

# ---- config do router: atualiza em lugar se existir, senao cria do template

if (-not (Test-Path $CcrConfigDir)) { New-Item -ItemType Directory -Path $CcrConfigDir | Out-Null }
$wroteConfig = $false
if (Test-Path $CcrConfigFile) {
    try {
        $cfg = Get-Content $CcrConfigFile -Raw | ConvertFrom-Json
        $updated = $false
        foreach ($provider in $cfg.Providers) {
            if ($provider.name -eq "nvidia") {
                $provider.api_key = $Key
                $updated = $true
            }
        }
        if ($updated) {
            [System.IO.File]::WriteAllText($CcrConfigFile, ($cfg | ConvertTo-Json -Depth 10), $Utf8NoBom)
            Write-Host "[glm] Config do router atualizada (api_key do provider nvidia)." -ForegroundColor DarkGray
            $wroteConfig = $true
        }
    } catch { }
}
if (-not $wroteConfig) {
    if (-not (Test-Path $TemplateFile)) {
        Write-Host "[glm] ERRO: template $TemplateFile nao encontrado." -ForegroundColor Red
        exit 1
    }
    $configText = [System.IO.File]::ReadAllText($TemplateFile).Replace("COLE_SUA_CHAVE_NVAPI_AQUI", $Key)
    [System.IO.File]::WriteAllText($CcrConfigFile, $configText, $Utf8NoBom)
    Write-Host "[glm] Config do router criada a partir do template." -ForegroundColor DarkGray
}

# ---- router ja de pe? reinicia para aplicar a chave ------------------------

$routerUp = $false
try {
    Invoke-WebRequest -Uri "http://127.0.0.1:3456" -UseBasicParsing -TimeoutSec 2 | Out-Null
    $routerUp = $true
} catch {
    if ($_.Exception.Response) { $routerUp = $true }
}
if ($routerUp) {
    Write-Host "[glm] Reiniciando o router para aplicar a chave..." -ForegroundColor DarkGray
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "ccr", "restart" -WindowStyle Hidden -Wait
}

Write-Host "[glm] Login concluido: chave instalada no .env e na config do router." -ForegroundColor Green
exit 0
