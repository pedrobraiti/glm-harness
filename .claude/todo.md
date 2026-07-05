# TODO

Plano vivo do projeto. Tarefas e subtarefas, marcadas conforme concluídas.

## Em progresso
- [ ] Corrigir erro 400 `Unsupported parameter(s): reasoning` (impedir Claude Code de enviar thinking pro NVIDIA)
- [ ] Smoke test: `glm -p` responde com GLM ponta a ponta

## Próximas
- [ ] Branding GLM: cópia local do Claude Code patchada (roxo + "GLM" no lugar de "Claude") chamada pelo launcher
- [ ] Atualizar README com uso, arquitetura final e ressalvas de rate limit
- [ ] Teste interativo real (sessão `glm` de verdade) e observar 429 de concorrência

## Concluído
- [x] Setup inicial do projeto (.claude/, git, repo privado)
- [x] Instalar claude-code-router v2.0.0 e configurar provider NVIDIA (z-ai/glm-5.2)
- [x] Validar tradução Anthropic→OpenAI→NVIDIA no router (resposta real do GLM)
- [x] Launcher `glm.ps1` + função `glm` no $PROFILE + `glm.cmd` no PATH (npm dir)
- [x] `.env` / `.env.example` / `.gitignore`
