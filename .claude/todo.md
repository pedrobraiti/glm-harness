# TODO

Plano vivo do projeto. Tarefas e subtarefas, marcadas conforme concluídas.

## Em progresso
(nada — núcleo + rate limiter entregues)

## Próximas
- [ ] Teste interativo real (sessão `glm` aberta pelo usuário): confirmar visual roxo/"GLM Harness" e observar o limiter sob rajadas reais
- [ ] Deletar repo antigo `pedrobraiti/OpenSource-LLM-on-ClaudeCode` — bloqueado: o `gh` precisa do escopo `delete_repo`; o usuário deve rodar `gh auth refresh -h github.com -s delete_repo` e depois `gh repo delete pedrobraiti/OpenSource-LLM-on-ClaudeCode --yes`
- [ ] Remover a raiz vazia `..\OS-CC-MCP` (conteúdo já apagado; raiz presa por outro processo — some ao fechar o processo que a segura)
- [ ] Se o free tier sufocar no uso real: migrar o router pro endpoint pago da z.ai (Caminho A) — só trocar provider/chave na config do ccr

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
- [x] Rate limiter (`launcher/rate-limiter.mjs`, porta 3457): fila com concorrência limitada, pausa total em 429 e retomada automática; config hot-reload em `limiter-config.json`; comando `/requisitions` no glm-home; launcher integra e sobe sozinho
- [x] Apagar conteúdo da pasta antiga `..\OS-CC-MCP` (raiz vazia ficou presa por handle de outro processo)
- [x] Repo antigo `OpenSource-LLM-on-ClaudeCode` deletado pelo usuário (após refresh do escopo delete_repo)
- [x] Skills próprias do GLM: cópias de find-skills/frontend-design/vizier + comando /setup + agente vizier-research-envoy em `glm-home\` (skills/commands/agents); CLAUDE.md de identidade ensina onde vivem e como editar; validado em sessão real
- [x] Memória global persistente do GLM (`glm-home\memory\`): índice MEMORY.md importado em toda sessão via @import no CLAUDE.md, regras de um-fato-por-arquivo com frontmatter, semeada com perfil do usuário; validado em sessão real (GLM gravou memória + atualizou índice sozinho e já respondeu em PT-BR por causa da memória semeada)
- [x] Paridade de experiência com a Claude: rules (ESSENTIALS/BEST_PRACTICES) importadas, hooks Stop+Notification adaptados (paths e branding GLM), plugins copiados (github + rust-analyzer-lsp), MCPs registrados (serena, context7, playwright, scout) — ibkr/crypto (execução de trading) deixados de fora por segurança; settings.json espelhado sem o statusline vibe-ads/spinner de propaganda; validado: 5 MCPs conectados e sessão real respondendo tudo
