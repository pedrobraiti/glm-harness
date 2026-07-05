# glm.ps1 — abre o Claude Code com o GLM 5.2 como cérebro da sessão.
#
# Como funciona: seta credencial de gateway APENAS neste processo e aponta o
# Claude Code pro claude-code-router local (porta 3456), que traduz
# Anthropic Messages <-> OpenAI Chat Completions e despacha pro endpoint da
# NVIDIA (z-ai/glm-5.2). Um `claude` aberto em outro terminal não vê essas
# variáveis e continua na assinatura Max.

$RouterUrl = "http://127.0.0.1:3456"

function Test-RouterUp {
    try {
        Invoke-WebRequest -Uri $RouterUrl -UseBasicParsing -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        # Qualquer resposta HTTP (mesmo 404) significa que o servidor está de pé
        return ($null -ne $_.Exception.Response)
    }
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

# Credencial de gateway: escopo deste processo. O router local nao valida o
# token (sem APIKEY na config), mas a presenca dele garante que este processo
# NAO usa a assinatura Max.
$env:ANTHROPIC_BASE_URL = $RouterUrl
$env:ANTHROPIC_AUTH_TOKEN = "glm-local"

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

# Menos requisicoes laterais -> menos chance de esbarrar no limite de
# concorrencia (~2 em voo) do free tier da NVIDIA.
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"

# NVIDIA rejeita o parametro `reasoning` que o router gera a partir do
# `thinking` do Claude Code (400). O GLM 5.2 ja pensa em "max" por default,
# entao desligar o thinking do lado do cliente nao perde qualidade.
$env:MAX_THINKING_TOKENS = "0"
$env:CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1"

claude @args
