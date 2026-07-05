# 03 — Achados técnicos (medidos/verificados)

> Não repita estes testes — foram medidos ao vivo. Parta daqui.

## 1. Limite real da NVIDIA free tier (GLM `z-ai/glm-5.2`)

**O limite é de CONCORRÊNCIA, não de throughput.** Medido ao vivo:

- **21 requisições sequenciais** (uma após a outra) em 43s → **todas passaram**. Nenhum 429.
- **64 requisições concorrentes** (rajada, todas na mesma janela de <1s) → **só 2 passaram, 62 tomaram 429 instantâneo**.
- Conclusão: o teto é **~2 requisições simultâneas em voo**, não "X por minuto".
- **O bloqueio 429 se ESTENDE a cada contato** durante o bloqueio. Depois da rajada, o endpoint ficou 429 por **horas** (nem 10 min de silêncio liberaram) — provavelmente somou com cota horária/diária esgotada por ~100 requests de teste no dia. Recuperação exige **silêncio total prolongado**.

**Implicação pro launcher:** o Claude Code interativo dispara **rajadas** de requisições → bate no muro de concorrência 2 → **o free tier da NVIDIA é impróprio pra uso interativo**. Serve pra tarefa sequencial pontual, não pra ser terminal principal. (No projeto MCP antigo funcionava porque o loop era single-flight, 1 req por vez.)

## 2. Parâmetros de "thinking" do GLM-5.2

Confirmado na doc oficial (Context7, repo `zai-org/glm-5`) **e verificado ao vivo no endpoint da NVIDIA**:

| Parâmetro | Valores | NVIDIA (`z-ai/glm-5.2`) | Observação |
|---|---|---|---|
| `reasoning_effort` | `"max"` (default) \| `"high"` | ✅ **200 OK** (aceito) | `max` é o **default do modelo** — não precisa setar pra ter qualidade máxima. `high` = menos thinking (mais rápido). |
| `enable_thinking` | `true` \| `false` | ❌ **400 "Unsupported parameter"** | NVIDIA **rejeita**. Funciona no endpoint próprio da z.ai. |

- Ou seja: a qualidade "thinking max" que o pessoal elogia **já é o baseline** do GLM 5.2 (max é default). Não é preciso "ligar" nada.
- São params do **corpo da requisição** (`extra_body` no SDK OpenAI). Relevante se o Caminho B expuser esse controle; no Caminho A (Anthropic-compatível) o mapeamento pode diferir — confirmar na doc da z.ai.

## 3. Qualidade do GLM 5.2 (anedótico, mas forte)

Post de um dev sênior (3 assinaturas Max) no Reddit: com **thinking em "max"**, o GLM 5.2 via Claude Code (endpoint Anthropic-compatível) lhe pareceu **à altura do Opus 4.8 em coding e planejamento** — em DB, backend de pagamentos, debugging Laravel/React. Anedótico e sem benchmark, mas de alguém crível. Ele também roda DeepSeek V4 como implementer (~Sonnet 4.6). Reforça que **vale a pena** ter o GLM como cérebro de terminal.

- O launcher dele (referência, **Linux-focado**, mas com scripts de exemplo pra Windows): `github.com/phase3dev/claude-code-workarounds` (+ Gists com só o código de launch do GLM). Útil como referência de implementação — mas confirmar tudo, não copiar cego.

## 4. Onde está a chave da NVIDIA

`C:\Users\ACS Gamer\Documents\vscode-local\GLM-5.2-NVDA\.env` → linha `NVIDIA_API_KEY=...`. Reutilizável se testar o Caminho B. **Não** foi colada em nenhum doc (segredo).

## 5. Ferramentas de tradução prontas (pro Caminho B)

- **`claude-code-router`** (musistudio) — roteia Claude Code a vários providers, faz a tradução Anthropic↔OpenAI e roteamento por modelo (inclusive o haiku/fast). Base mais robusta.
- **LiteLLM** — proxy com passthrough Anthropic `/v1/messages` unificado.
- **z.ai docs** — pro Caminho A (endpoint Anthropic nativo), não precisa de proxy.
