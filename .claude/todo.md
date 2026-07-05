# TODO

Plano vivo do projeto. Tarefas e subtarefas, marcadas conforme concluídas.

## Em progresso
- [ ] Branding GLM: cópia local do Claude Code patchada (roxo + "GLM" no lugar de "Claude") chamada pelo launcher

## Próximas
- [ ] Atualizar README com uso, arquitetura final e ressalvas de rate limit
- [ ] Teste interativo real (sessão `glm` de verdade) e observar 429 de concorrência

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
