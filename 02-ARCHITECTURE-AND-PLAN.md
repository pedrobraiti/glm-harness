# 02 — Arquitetura e plano de implementação

> Como o Claude Code roteia a um modelo custom, os dois caminhos, os gotchas (env vars **verificadas** na doc oficial do Claude Code v2.1.196+), e o plano.

## 1. Como o Claude Code fala com um modelo custom

O Claude Code manda requisições no formato **Anthropic Messages API** (`/v1/messages`) pra `ANTHROPIC_BASE_URL`. Para rotear ao GLM, o launcher seta variáveis de ambiente **só no processo do `glm`**. Escopo por-processo **confirmado**: um `claude` iniciado sem essas vars não é afetado (continua Max).

### Variáveis de ambiente (nomes confirmados, Claude Code v2.1.196+)

**Endpoint e auth:**
| Variável | Para quê |
|---|---|
| `ANTHROPIC_BASE_URL` | URL base do endpoint custom. Ao apontar pra host não-Anthropic, o Claude Code **desliga Remote Control e o tool-search por padrão** (reabilitar com `ENABLE_TOOL_SEARCH=true`). |
| `ANTHROPIC_AUTH_TOKEN` | Credencial enviada como `Authorization: Bearer`. |
| `ANTHROPIC_API_KEY` | Credencial enviada como `x-api-key`. Precede o login salvo. |
| `apiKeyHelper` | Comando shell que emite a credencial (vai nos **dois** headers). Fica no settings, não no shell. TTL de cache: `CLAUDE_CODE_API_KEY_HELPER_TTL_MS`. |

**Modelos** (o Claude Code usa mais de um!):
| Variável | Para quê |
|---|---|
| `ANTHROPIC_MODEL` | Modelo principal. |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Modelo de **tarefas de fundo/rápidas** (títulos, resumos). **Substitui o antigo `ANTHROPIC_SMALL_FAST_MODEL` (deprecado).** |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` / `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_FABLE_MODEL` | Modelos por classe, caso o CC os invoque. |

> ⚠️ **Gotcha nº1 (o mais comum de esquecer):** se você mapear só o `ANTHROPIC_MODEL` e esquecer o `ANTHROPIC_DEFAULT_HAIKU_MODEL`, o Claude Code tenta chamar um modelo Haiku que o endpoint do GLM não conhece → erros em tarefas laterais. **Aponte os dois pro GLM.**

**Outras úteis:**
| Variável | Para quê |
|---|---|
| `ENABLE_TOOL_SEARCH=true` | Reabilita tool-search (desligado por padrão em host não-Anthropic). |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` | Desliga o "adaptive thinking" se o upstream rejeitar. |
| `ANTHROPIC_CUSTOM_HEADERS` | Headers extras (multi-linha). |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` / `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | Limites, se o gateway impuser janela menor que a nativa. |
| `NODE_EXTRA_CA_CERTS` | CA bundle, se houver proxy TLS corporativo. |

## 2. Os dois caminhos (A decisão que define o projeto)

### Caminho A — endpoint Anthropic-compatível oficial (z.ai / GLM Coding Plan)  ✅ recomendado
- O GLM tem um endpoint que **já fala Anthropic Messages** nativamente (feito pra Claude Code).
- Launcher = **só env vars**. **Zero proxy.**
- **Pago** (barato), mas **robusto**, sem o inferno de rate limit do free tier.
- É o que o dev sênior do Reddit usa (ver `03-FINDINGS.md`).
- **A confirmar quando formos montar:** URL base exata do endpoint Anthropic da z.ai e o `model id` (ex.: `glm-4.6`/`glm-5.2`) — verificar na doc da z.ai (não chutar).

### Caminho B — endpoint grátis/OpenAI-compatível (NVIDIA) + proxy de tradução
- A NVIDIA (`integrate.api.nvidia.com/v1`) é **OpenAI-compatível**, não Anthropic. Precisa de um **proxy** que traduza Anthropic Messages ↔ OpenAI Chat Completions (incluindo `tool_use`/`tool_result` e streaming).
- **Grátis**, mas: o free tier da NVIDIA trava em **concorrência ~2 requisições em voo** e estende bloqueio a cada contato (medido — ver `03-FINDINGS.md`). Uma sessão interativa do Claude Code **dispara rajadas** (principal + haiku + paralelismo) → **vai sufocar**. Provavelmente **inviável** pra uso interativo real.
- Se for por aqui, **não escrever o tradutor do zero**: usar `claude-code-router` (musistudio) ou `LiteLLM` (tem passthrough `/v1/messages`). E preferir um endpoint pago que aguente (OpenRouter, etc.) em vez do NVIDIA grátis.

**Recomendação:** **Caminho A** pra um `glm` que você usa de verdade o dia todo. O grátis serve pra brincar/testar, não pra ser seu terminal principal.

## 3. Desenho do launcher (Windows)

O `glm` é um shim fino que seta as env vars e chama `claude`, isolado no processo:

```powershell
# glm.ps1  (exemplo conceitual — valores reais vêm do .env / config)
$env:ANTHROPIC_BASE_URL   = "<endpoint>"
$env:ANTHROPIC_AUTH_TOKEN = "<token>"
$env:ANTHROPIC_MODEL                = "<glm-model-id>"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL  = "<glm-model-id>"   # não esquecer!
claude @args
```

- **Exposição no PATH:** um `glm.cmd`/função no `$PROFILE` do PowerShell, ou um `glm.cmd` numa pasta que esteja no PATH, apontando pro script em `CC_Kernel`. O **projeto mora em `CC_Kernel`**; só o shim precisa estar acessível.
- **Segredos:** token/keys em `CC_Kernel\.env` (git-ignored), espelhado em `.env.example`. O launcher lê do `.env`.
- **Isolamento garantido:** como as vars são setadas no processo do `glm`, o `claude` normal nunca as vê.

## 4. Gotchas / riscos (resumo)

1. **Mapear os dois modelos** (principal + `ANTHROPIC_DEFAULT_HAIKU_MODEL`).
2. **"Não suportado" pela Anthropic:** rotear o Claude Code a modelo não-Claude via gateway funciona mas é oficialmente não-suportado → pode quebrar a cada update do Claude Code. Pinar/observar versão.
3. **Caminho B** precisa traduzir tool calls + streaming corretamente (por isso usar router pronto).
4. **Tool-search e Remote Control** desligam em host não-Anthropic (reabilitar tool-search se quiser).
5. **Prompt caching / cache_control** do Anthropic pode ser ignorado pelo endpoint — só perda de otimização, não quebra.

## 5. Plano de implementação (quando o usuário mandar)

1. Escolher **Caminho A ou B** (decisão aberta abaixo).
2. Criar estrutura em `CC_Kernel`: `.env`/`.env.example`, pasta `.claude/` de memória (handoff/context/todo/decisions como padrão do usuário), `README` executável.
3. **A:** obter/config a key da z.ai; confirmar URL base + model id na doc oficial. **B:** subir e configurar o router (claude-code-router/LiteLLM) apontando pro endpoint OpenAI-compatível.
4. Escrever o launcher (`glm.ps1` + shim no PATH), com env-scoping e mapeamento dos dois modelos.
5. **Smoke test:** rodar `glm`, confirmar que responde com GLM; abrir `claude` em paralelo e confirmar que continua no Max (checar via `/status` ou billing).
6. Documentar uso no README e registrar decisões.

## 6. Decisões abertas (resolver no chat novo)

- [ ] **Caminho A (z.ai pago) ou B (grátis/OpenRouter + proxy)?**
- [ ] Se A: já tem conta/plano na z.ai, ou precisa criar? Confirmar URL base + model id oficiais.
- [ ] Nome/forma do comando: `glm` puro? Aceitar flags repassadas pro `claude` (`glm @args`)?
- [ ] Versionar `CC_Kernel` no git / criar repo? (o antigo será deletado — ver `01-BRIEFING §6`)
