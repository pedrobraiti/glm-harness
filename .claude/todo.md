# TODO

Plano vivo do projeto. Tarefas e subtarefas, marcadas conforme concluídas.

## Em progresso
(nada — núcleo entregue)

## Próximas
- [ ] Teste interativo real (sessão `glm` aberta pelo usuário): confirmar visual roxo/"GLM Harness" e observar se rajadas da sessão tomam 429 da NVIDIA
- [ ] Se o free tier sufocar no uso real: migrar o router pro endpoint pago da z.ai (Caminho A) — só trocar provider/chave na config do ccr
- [ ] Deletar repo antigo `pedrobraiti/OpenSource-LLM-on-ClaudeCode` e pasta `..\OS-CC-MCP` (autorizado no briefing §6, ainda não executado)

## Concluído
- [x] Setup inicial do projeto (.claude/, git, repo privado `pedrobraiti/glm-harness`)
- [x] Instalar claude-code-router v2.0.0 e configurar provider NVIDIA (z-ai/glm-5.2)
- [x] Validar tradução Anthropic→OpenAI→NVIDIA no router (resposta real do GLM)
- [x] Launcher `glm.ps1` + função `glm` no $PROFILE + `glm.cmd` no PATH (npm dir)
- [x] `.env` / `.env.example` / `.gitignore`
- [x] Corrigir 400 `Unsupported parameter(s): reasoning` (MAX_THINKING_TOKENS=0 + DISABLE_ADAPTIVE_THINKING)
- [x] Home próprio do glm (`glm-home/` via CLAUDE_CONFIG_DIR) com CLAUDE.md de identidade/autoconfiguração
- [x] Identidade verdadeira do modelo (ANTHROPIC_MODEL=z-ai/glm-5.2; GLM se reconhece como GLM)
- [x] Smoke test ponta a ponta: `glm -p` responde como GLM 5.2 via NVIDIA
- [x] Prova de isolamento: BASE_URL honrado por-processo (porta morta → ConnectionRefused); `claude` sem env vars segue no Max
- [x] Branding GLM Harness: binário vendorado patchado (roxo #A855F7 + "GLM Harness", mascote roxo) via `apply-glm-branding.mjs`; launcher usa o binário patchado com fallback pro claude global
- [x] README reescrito com uso real, arquitetura e rebuild
