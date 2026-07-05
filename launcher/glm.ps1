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

# Primeiro uso: pula o wizard de onboarding no home novo.
$StateFile = Join-Path $GlmHome ".claude.json"
if (-not (Test-Path $StateFile)) {
    '{ "hasCompletedOnboarding": true, "theme": "dark" }' | Set-Content -Path $StateFile -Encoding Ascii
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

# Janela de contexto de 1M: o Claude Code assume 200k para modelo que ele nao
# conhece e auto-compactaria cedo demais. Estes dois andam juntos: o
# auto-compact passa a mirar 1M e o statusline mede a barra contra o mesmo 1M.
$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000"
$env:GLM_CONTEXT_WINDOW = "1000000"

# Binario com branding GLM (roxo + "GLM Harness"), gerado por
# apply-glm-branding.mjs a partir da copia vendorada. Se nao existir
# (ex.: clone novo sem `npm install --prefix vendor` + patch), cai no
# claude global — funciona igual, so sem o visual.
$GlmExe = Join-Path (Split-Path $PSScriptRoot -Parent) "vendor\glm-claude.exe"
if (Test-Path $GlmExe) {
    & $GlmExe @args
} else {
    claude @args
}
