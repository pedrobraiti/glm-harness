# GLM Harness

Comando de terminal **`glm`** que abre a experiência completa do Claude Code rodando o **GLM 5.2** como cérebro da sessão — com visual próprio (roxo, "GLM Harness") — enquanto o comando `claude` normal continua na assinatura **Max**, intacto. Dois comandos, dois cérebros, sem conflito.

**Status: funcional.** `glm -p "which model are you?"` → *"I'm GLM 5.2 (z-ai/glm-5.2), running in the harness via the glm command."*

## Uso

```powershell
glm                 # sessão interativa do GLM Harness (qualquer pasta)
glm -p "pergunta"   # modo print, sem sessão
claude              # Claude normal, assinatura Max — não é afetado
```

No **primeiro uso** o launcher roda um wizard: escolha de tema + "login" (abre a página da chave da NVIDIA no navegador, valida a chave colada e grava `.env` + config do router). Dentro do glm, **`/login`** refaz o fluxo (ex.: trocar de chave).

O comando existe como função no `$PROFILE` do PowerShell e como `glm.cmd` em `%APPDATA%\npm` (funciona em qualquer shell).

## Arquitetura

```
glm (PowerShell/cmd)
 └─ launcher/glm.ps1          seta env vars SÓ neste processo:
     ANTHROPIC_BASE_URL=http://127.0.0.1:3457   (rate limiter local)
     ANTHROPIC_AUTH_TOKEN=glm-local              (garante que o Max não é usado)
     ANTHROPIC_MODEL=z-ai/glm-5.2                (identidade verdadeira)
     MAX_THINKING_TOKENS=0                       (NVIDIA rejeita `reasoning`)
     CLAUDE_CONFIG_DIR=glm-home\                 (home próprio, separado do ~/.claude)
     └─ vendor/glm-claude.exe  Claude Code 2.1.200 patchado (roxo + "GLM Harness")
         └─ launcher/rate-limiter.mjs (porta 3457)  fila + pausa/retomada em 429
             └─ claude-code-router (porta 3456)      traduz Anthropic ↔ OpenAI
                 └─ NVIDIA integrate.api.nvidia.com  z-ai/glm-5.2 (free tier)
```

- **Isolamento:** as env vars morrem com o processo do `glm`. Um `claude` aberto em paralelo nunca as vê (provado: BASE_URL numa porta morta → ConnectionRefused só no processo com a var).
- **Rate limiter (`launcher/rate-limiter.mjs`):** feito sob medida pro free tier da NVIDIA. Fila com limite de concorrência (nada é descartado); ao tomar um 429, **pausa TODO o tráfego em silêncio total** (contato durante o bloqueio o estende) e **retoma sozinho** após o cooldown — a sessão só percebe uma resposta demorada, sem "continue" manual. Config em `limiter-config.json` (**hot-reload** — editar já vale): `maxConcurrent` (default 2), `cooldownSeconds` (default 75), `maxAttempts` (default 12). Dentro do `glm`, o comando **`/requisitions`** mostra/ajusta esses limites (`/requisitions 1`, `/requisitions 1 90`). Estado vivo: `http://127.0.0.1:3457/glm-limiter/health`; logs em `logs/limiter.log`.
- **Router:** [claude-code-router](https://github.com/musistudio/claude-code-router) v2.0.0, config em `~/.claude-code-router/config.json` (provider `nvidia` + chave). Serviço: `ccr status` / `ccr restart`. O launcher sobe o serviço sozinho se estiver fora do ar.
- **Home próprio (`glm-home/`):** config, histórico e memória global do GLM separados do Claude/Max. O `glm-home/CLAUDE.md` ensina o GLM quem ele é e onde vivem as próprias configurações — dá pra pedir *pro próprio glm* mudar a config dele.
- **Branding:** `launcher/apply-glm-branding.mjs` gera `vendor/glm-claude.exe` a partir do pacote npm vendorado, trocando (em bytes de mesmo comprimento) `"Claude Code"` → `"GLM Harness"` e o laranja da marca `rgb(215,119,87)` → roxo `rgb(168,85,247)` (inclusive o mascote) + shimmers. O binário do `claude` global não é tocado.

## Instalar numa máquina nova

Veja **[`INSTALL.md`](INSTALL.md)** — guia completo, escrito para ser executado por uma sessão do Claude Code na máquina de destino (só a chave da NVIDIA depende do humano). Memórias pessoais não vêm no clone; cada instalação constrói a sua.

## Rebuild do zero (máquina nova / update do Claude Code)

```powershell
npm install -g @musistudio/claude-code-router
npm install --prefix vendor @anthropic-ai/claude-code@2.1.200
node launcher/apply-glm-branding.mjs
# função glm no $PROFILE + glm.cmd em %APPDATA%\npm apontando pro launcher/glm.ps1
# a config do router (~/.claude-code-router/config.json) é criada pelo wizard de login do primeiro `glm`
```

Segredos: `.env` (git-ignored, espelhado em `.env.example`) guarda a `NVIDIA_API_KEY`.

## Limitações conhecidas

- **Free tier da NVIDIA: ~2 requisições simultâneas em voo; o 429 se estende a cada novo contato** (medições em `03-FINDINGS.md`). Uso interativo pesado (subagentes paralelos, rajadas) pode sufocar. Se virar problema, o upgrade natural é o endpoint Anthropic-nativo pago da z.ai (Caminho A em `02-ARCHITECTURE-AND-PLAN.md`) — só trocar endpoint/chave no router.
- **O que esperar do free tier na prática** (medido, não teoria): o 429 da NVIDIA vem **sem nenhum header** de limite (nem `retry-after`), o castigo **se estende a cada contato** durante o bloqueio, e além da concorrência existe cota de volume invisível. O padrão de uso pesado é: funciona um bom tempo → seca → o limiter pausa em silêncio (statusline mostra `⏸ 429 · retoma em Xs`) → volta sozinho. **Regra de ouro: quando demorar, não cancele nem reenvie** — cada toque durante o bloqueio o estende. Uso leve/moderado: você provavelmente nem nota. Motor principal o dia todo: considere o endpoint pago.
- Rotear o Claude Code a modelo não-Claude é **oficialmente não-suportado** pela Anthropic → versão pinada (2.1.200); updates podem exigir re-patch (`apply-glm-branding.mjs` é reprodutível).
- Thinking do lado do cliente desligado (NVIDIA rejeita `reasoning`); o GLM 5.2 já raciocina em `max` por default no servidor — nada se perde.

## Documentação

1. [`01-BRIEFING.md`](01-BRIEFING.md) — história e decisões (por que launcher/gateway, por que o Max não é perdido).
2. [`02-ARCHITECTURE-AND-PLAN.md`](02-ARCHITECTURE-AND-PLAN.md) — env vars verificadas, os dois caminhos, gotchas.
3. [`03-FINDINGS.md`](03-FINDINGS.md) — medições reais (limites da NVIDIA, params de thinking do GLM).
4. [`reference/rationale-mcp-approach.md`](reference/rationale-mcp-approach.md) — contexto histórico (abordagem MCP abandonada).
