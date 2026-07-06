# glm.ps1 — abre o Claude Code com o GLM 5.2 como cérebro da sessão.
#
# Como funciona: seta credencial de gateway APENAS neste processo e aponta o
# Claude Code pro claude-code-router local (porta 3456), que traduz
# Anthropic Messages <-> OpenAI Chat Completions e despacha pro endpoint da
# NVIDIA (z-ai/glm-5.2). Um `claude` aberto em outro terminal não vê essas
# variáveis e continua na assinatura Max.

$RouterUrl = "http://127.0.0.1:3456"
$LimiterUrl = "http://127.0.0.1:3457"
$ProjectRoot = Split-Path $PSScriptRoot -Parent

function Test-HttpUp([string]$Url) {
    try {
        Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        # Qualquer resposta HTTP (mesmo 404) significa que o servidor está de pé
        return ($null -ne $_.Exception.Response)
    }
}
function Test-RouterUp { Test-HttpUp $RouterUrl }
function Test-LimiterUp { Test-HttpUp "$LimiterUrl/glm-limiter/health" }

$IsPrintMode = ($args -contains "-p") -or ($args -contains "--print")

# "Login" do harness: sem chave NVIDIA no .env ou sem config do router, roda o
# assistente (abre a pagina da chave no navegador, valida na NVIDIA e grava
# .env + config). Com chave no .env e so a config faltando, ele resolve sozinho
# sem perguntar nada.
$EnvFile = Join-Path $ProjectRoot ".env"
$CcrConfigFile = Join-Path $HOME ".claude-code-router\config.json"
$HasNvidiaKey = $false
if (Test-Path $EnvFile) {
    $HasNvidiaKey = [bool](Get-Content $EnvFile | Where-Object { $_ -match '^\s*NVIDIA_API_KEY\s*=\s*nvapi-' })
}
if (-not $HasNvidiaKey -or -not (Test-Path $CcrConfigFile)) {
    if (-not $HasNvidiaKey -and $IsPrintMode) {
        Write-Host "[glm] Sem chave NVIDIA configurada. Rode 'glm' (sem -p) uma vez para fazer o login." -ForegroundColor Red
        exit 1
    }
    & "$PSScriptRoot\glm-login.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Test-RouterUp)) {
    Write-Host "[glm] Subindo o claude-code-router..." -ForegroundColor DarkGray
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "ccr", "start" -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(20)
    while (-not (Test-RouterUp)) {
        if ((Get-Date) -gt $deadline) {
            Write-Host "[glm] ERRO: o router nao subiu em 20s. Rode 'ccr start' manualmente para ver o erro." -ForegroundColor Red
            exit 1
        }
        Start-Sleep -Milliseconds 500
    }
    Write-Host "[glm] Router pronto." -ForegroundColor DarkGray
}

if (-not (Test-LimiterUp)) {
    Write-Host "[glm] Subindo o rate limiter..." -ForegroundColor DarkGray
    $LogDir = Join-Path $ProjectRoot "logs"
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
    Start-Process -FilePath "node" -ArgumentList "`"$PSScriptRoot\rate-limiter.mjs`"" -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $LogDir "limiter.log") `
        -RedirectStandardError (Join-Path $LogDir "limiter-err.log")
    $deadline = (Get-Date).AddSeconds(15)
    while (-not (Test-LimiterUp)) {
        if ((Get-Date) -gt $deadline) {
            Write-Host "[glm] ERRO: o rate limiter nao subiu em 15s. Veja logs\limiter-err.log" -ForegroundColor Red
            exit 1
        }
        Start-Sleep -Milliseconds 300
    }
    Write-Host "[glm] Rate limiter pronto." -ForegroundColor DarkGray
}

# Credencial de gateway: escopo deste processo. O router local nao valida o
# token (sem APIKEY na config), mas a presenca dele garante que este processo
# NAO usa a assinatura Max. O trafego passa pelo rate limiter (fila +
# pausa/retomada automatica em 429), que encaminha ao router.
$env:ANTHROPIC_BASE_URL = $LimiterUrl
$env:ANTHROPIC_AUTH_TOKEN = "glm-local"

# Timeout folgado do lado do cliente: durante um cooldown de 429 a requisicao
# fica presa na fila do limiter e conclui sozinha depois.
$env:API_TIMEOUT_MS = "600000"

# Identidade verdadeira: sem isso o system prompt do Claude Code diria ao GLM
# que ele e um modelo Claude (e ele acreditaria). O router roteia qualquer
# nome pro provider nvidia, mas o nome certo mantem o modelo ciente de si.
$env:ANTHROPIC_MODEL = "z-ai/glm-5.2"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "z-ai/glm-5.2"

# Home proprio do glm: config, historico e memoria global (CLAUDE.md de
# identidade) separados do ~/.claude da Claude/Max.
$GlmHome = (Resolve-Path "$PSScriptRoot\..\glm-home").Path
$env:CLAUDE_CONFIG_DIR = $GlmHome

# Primeiro uso: pula o wizard de onboarding nativo (que ofereceria login
# Anthropic — nao se aplica aqui) e faz a parte util dele por conta propria:
# pergunta o tema. A escolha vai pro settings.local.json (git-ignored), que
# vence o settings.json versionado via --settings.
$StateFile = Join-Path $GlmHome ".claude.json"
if (-not (Test-Path $StateFile)) {
    $Theme = "dark"
    if (-not $IsPrintMode) {
        Write-Host ""
        Write-Host "[glm] Tema do GLM Harness:" -ForegroundColor Magenta
        Write-Host "[glm]   1) Escuro (padrao)   2) Claro   3) Escuro daltonico   4) Claro daltonico"
        $themeChoice = Read-Host "[glm] Escolha (Enter = 1)"
        switch ("$themeChoice".Trim()) {
            "2" { $Theme = "light" }
            "3" { $Theme = "dark-daltonized" }
            "4" { $Theme = "light-daltonized" }
        }
    }
    ('{ "hasCompletedOnboarding": true, "theme": "' + $Theme + '" }') | Set-Content -Path $StateFile -Encoding Ascii
    $LocalSettingsFile = Join-Path $GlmHome "settings.local.json"
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    if (Test-Path $LocalSettingsFile) {
        try {
            $localSettings = Get-Content $LocalSettingsFile -Raw | ConvertFrom-Json
            $localSettings | Add-Member -NotePropertyName "theme" -NotePropertyValue $Theme -Force
            [System.IO.File]::WriteAllText($LocalSettingsFile, ($localSettings | ConvertTo-Json -Depth 10), $Utf8NoBom)
        } catch { }
    } else {
        [System.IO.File]::WriteAllText($LocalSettingsFile, ('{ "theme": "' + $Theme + '" }'), $Utf8NoBom)
    }
}

# Primeiro uso: semeia a memoria global do GLM (pessoal -> fica fora do git;
# um clone novo nasce com o indice vazio e o GLM preenche com o tempo).
# Nota: este arquivo .ps1 e ASCII puro de proposito (PS 5.1 le .ps1 sem BOM
# como ANSI); por isso o seed vai sem acentos.
$MemoryIndex = Join-Path $GlmHome "memory\MEMORY.md"
if (-not (Test-Path $MemoryIndex)) {
    New-Item -ItemType Directory -Force (Join-Path $GlmHome "memory") | Out-Null
    $seedLines = @(
        "# Indice da memoria global do GLM 5.2",
        "",
        "> Uma linha por memoria, formato '- [Titulo](arquivo.md) - gancho'. Nunca coloque o conteudo da memoria aqui - so o ponteiro. Este indice e carregado em toda sessao.",
        ""
    )
    $seedLines | Set-Content -Path $MemoryIndex -Encoding UTF8
}

# Menos requisicoes laterais -> menos chance de esbarrar no limite de
# concorrencia (~2 em voo) do free tier da NVIDIA.
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"

# NVIDIA rejeita o parametro `reasoning` que o router gera a partir do
# `thinking` do Claude Code (400). O GLM 5.2 ja pensa em "max" por default,
# entao desligar o thinking do lado do cliente nao perde qualidade.
$env:MAX_THINKING_TOKENS = "0"
$env:CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1"

# Janela de contexto: o GLM 5.2 suporta 1M, mas o endpoint GRATUITO da NVIDIA
# corta em ~202k tokens e falha com HTTP 500 generico acima disso (limite
# fisico dos nos compartilhados, confirmado pela comunidade). 180k da margem
# para o auto-compact agir ANTES do precipicio. Estes dois andam juntos: o
# auto-compact mira 180k e o statusline mede a barra contra o mesmo valor.
# (Se um dia migrar para endpoint pago com 1M real, suba os dois.)
$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = "180000"
$env:GLM_CONTEXT_WINDOW = "180000"

# Overrides LOCAIS de settings (git-ignored): preferencias pessoais que nao
# devem ir pro GitHub (ex.: permissions.defaultMode=bypassPermissions). Entra
# por cima de TODOS os outros settings via --settings (nivel CLI).
#
# Blindagem de identidade: o nivel CLI vence tambem settings de PROJETO.
# Sem isso, abrir o glm numa pasta com .claude\settings.json proprio trocava
# o visual — caso classico: na pasta HOME do usuario, o settings global do
# Claude Code vira "settings de projeto" (tema light-ansi, statusline de
# terceiros, model claude) e descaracterizava o GLM. Aqui garantimos que as
# chaves de identidade sempre existam no arquivo local (so preenche o que
# faltar; escolhas do dono ficam intactas).
$LocalSettings = Join-Path $GlmHome "settings.local.json"
$SettingsUtf8 = New-Object System.Text.UTF8Encoding($false)
if (-not (Test-Path $LocalSettings)) {
    [System.IO.File]::WriteAllText($LocalSettings, '{ }', $SettingsUtf8)
}
try {
    $glmSettings = Get-Content $LocalSettings -Raw | ConvertFrom-Json
    $settingsChanged = $false
    if (-not $glmSettings.PSObject.Properties['theme']) {
        $glmSettings | Add-Member -NotePropertyName "theme" -NotePropertyValue "dark"
        $settingsChanged = $true
    }
    if (-not $glmSettings.PSObject.Properties['model']) {
        $glmSettings | Add-Member -NotePropertyName "model" -NotePropertyValue "z-ai/glm-5.2"
        $settingsChanged = $true
    }
    if (-not $glmSettings.PSObject.Properties['statusLine']) {
        $rootForward = $ProjectRoot -replace '\\', '/'
        $statusLine = New-Object PSObject
        $statusLine | Add-Member NoteProperty type "command"
        $statusLine | Add-Member NoteProperty command "node `"$rootForward/launcher/glm-statusline.mjs`""
        $statusLine | Add-Member NoteProperty padding 0
        $glmSettings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $statusLine
        $settingsChanged = $true
    }
    if (-not $glmSettings.PSObject.Properties['spinnerVerbs']) {
        $spinnerVerbs = New-Object PSObject
        $spinnerVerbs | Add-Member NoteProperty mode "replace"
        $spinnerVerbs | Add-Member NoteProperty verbs @("Pensando", "Maquinando", "Conjurando", "Voando")
        $glmSettings | Add-Member -NotePropertyName "spinnerVerbs" -NotePropertyValue $spinnerVerbs
        $settingsChanged = $true
    }
    if ($settingsChanged) {
        [System.IO.File]::WriteAllText($LocalSettings, ($glmSettings | ConvertTo-Json -Depth 10), $SettingsUtf8)
    }
} catch { }
$ExtraArgs = @("--settings", $LocalSettings)

# Binario com branding GLM (roxo + "GLM Harness"), gerado por
# apply-glm-branding.mjs a partir da copia vendorada. Se nao existir
# (ex.: clone novo sem `npm install --prefix vendor` + patch), cai no
# claude global — funciona igual, so sem o visual.
$GlmExe = Join-Path (Split-Path $PSScriptRoot -Parent) "vendor\glm-claude.exe"
if (Test-Path $GlmExe) {
    & $GlmExe @ExtraArgs @args
} else {
    claude @ExtraArgs @args
}
