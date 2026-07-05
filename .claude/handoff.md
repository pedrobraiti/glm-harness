# Handoff — de onde parei

> **Propósito:** este arquivo serve para que um chat NOVO saiba com precisão "de onde eu parei",
> de forma relativamente detalhada. É o PRIMEIRO arquivo que a próxima sessão lê.
> Mantenha-o vivo e específico — detalhado o bastante para retomar sem reconstruir o raciocínio.

**Última atualização:** 2026-07-05 (núcleo + branding + rate limiter entregues)

## Onde parei
**Projeto entregue e funcional, agora com rate limiter.** Cadeia: `glm` → `glm.ps1` → `vendor/glm-claude.exe` (patchado roxo/"GLM Harness") → **`launcher/rate-limiter.mjs` (porta 3457: fila com concorrência limitada; em 429 pausa TODO o tráfego em silêncio e retoma sozinho)** → claude-code-router (3456) → NVIDIA. Config do limiter em `limiter-config.json` (hot-reload); comando `/requisitions` no glm-home mostra/ajusta. Smoke test passou pela cadeia completa; health em `http://127.0.0.1:3457/glm-limiter/health`. Falta: validação visual interativa pelo usuário e ver o limiter sob rajadas reais (o caminho de 429 ainda não foi exercitado ao vivo — só o caminho feliz).

## Contexto mental
Cadeia completa: `glm` (função no $PROFILE / glm.cmd no npm dir) → `launcher/glm.ps1` (env por-processo: BASE_URL=router:3456, AUTH_TOKEN, MODEL=z-ai/glm-5.2, MAX_THINKING_TOKENS=0, CLAUDE_CONFIG_DIR=glm-home) → `vendor/glm-claude.exe` (Claude Code 2.1.200 npm vendorado, patchado por `launcher/apply-glm-branding.mjs`: "Claude Code"→"GLM Harness" 906x, laranja rgb(215,119,87)→roxo rgb(168,85,247) 9x incl. `clawd_body` do mascote, shimmers 2x+2x — sempre bytes de mesmo comprimento) → claude-code-router 2.0.0 (config `~/.claude-code-router/config.json`, provider nvidia) → `integrate.api.nvidia.com` z-ai/glm-5.2.

Decisões/aprendizados importantes: (1) o pacote npm ≥2.1.x é só wrapper de binário nativo — o patch é binário, não em cli.js; (2) sem ANTHROPIC_MODEL o GLM se apresentava como "Claude Fable 5" (obedecia ao system prompt); (3) roteamento provado por falsificação (porta morta → ConnectionRefused), pois o log do ccr fica vazio; (4) 400 `reasoning` da NVIDIA resolvido desligando thinking no cliente (GLM já pensa em max no servidor).

## Próximo passo concreto
Usuário abre `glm` num terminal novo e confirma o visual roxo/"GLM Harness" e o comportamento do limiter em uso real. (Repo antigo já deletado pelo usuário; resta só a raiz vazia `..\OS-CC-MCP` presa por handle — some quando o processo que a segura fechar.)

## Skills do GLM (adicionado por último)
O glm-home agora tem `skills\` (find-skills, frontend-design, vizier — cópias independentes das do ~/.claude, vizier sem .venv/.git), `commands\` (requisitions, setup) e `agents\` (vizier-research-envoy). O CLAUDE.md de identidade tem seção "Suas skills são SUAS" ensinando que editar/criar skills é em `glm-home\skills\`. Validado em sessão real: o GLM lista as 3 skills e sabe o fluxo de edição. Nota: vizier no glm é referência/edição, não operacional (MCPs scout/valet não registrados no home dele).

## Sessões compartilhadas + /resume cruzado (adicionado por último)
`glm-home\projects` virou **junction** para `~\.claude\projects` — Claude e GLM veem as mesmas conversas no `/resume`, nos dois sentidos. Validado ao vivo: sessão criada com `claude -p` (codeword ABACAXI-42), retomada com `glm -p --resume <id>` → GLM lembrou o codeword e se manteve GLM. O CLAUDE.md do GLM explica o compartilhamento e manda não herdar identidade de turnos antigos. Atenção futura: transcripts da Claude podem conter blocos de thinking/tool_use que o ccr precisa converter — funcionou no teste; se um resume falhar, suspeitar disso. O junction é recriável com: `New-Item -ItemType Junction -Path glm-home\projects -Target ~\.claude\projects`.

## Paridade de experiência com a Claude (adicionado por último)
O glm-home agora replica o ambiente completo do usuário: `rules\` (ESSENTIALS + BEST_PRACTICES importadas no CLAUDE.md), `hooks\` (stop-memory-check.sh idêntico; notify-alert.sh com branding GLM e log próprio; registrados no settings.json com paths absolutos do glm-home), `plugins\` (cópia de ~/.claude/plugins; github + rust-analyzer-lsp habilitados), MCPs no `.claude.json` do home (serena, context7, playwright, scout). **Decisão de segurança: ibkr/crypto (execução real de trading) NÃO foram registrados** — só o scout (dados). Settings espelhado SEM o statusline `.vibe-ads` e o spinnerVerbs de propaganda (parecem adware no settings global do usuário — flagado a ele). Validado: `glm mcp list` mostra 5 conectados; sessão real confirma identidade/MCPs/memória/commits.

## Memória global do GLM (adicionado por último)
`glm-home\memory\` com índice `MEMORY.md` **importado em toda sessão** via `@memory/MEMORY.md` no CLAUDE.md de identidade (replica o comportamento da memória do Claude Code, brandado GLM 5.2, sem menção a Claude Code). Regras completas na seção "Sua memória global persistente" do CLAUDE.md: um fato por arquivo, frontmatter (name/description/metadata.type user|feedback|project|reference), atualizar índice, dedup, salvar por iniciativa própria. Semeada com `quem-e-o-usuario.md`. Validado ao vivo: pedi pra gravar um fato e o GLM criou o arquivo no formato certo, atualizou o índice e respondeu em PT-BR (efeito da memória semeada).

## Em aberto / armadilhas
- **Trust dialog:** o glm-home é novo — na primeira sessão interativa em cada pasta o harness vai perguntar "do you trust this folder?" de novo (estado por-home). Normal.
- Free tier NVIDIA: ~2 requisições em voo; 429 estende a cada contato. Sessões interativas disparam rajadas; se sufocar, Caminho A (z.ai pago) é só trocar provider na config do ccr.
- Versão pinada 2.1.200: update do Claude Code exige re-vendorar + re-rodar `apply-glm-branding.mjs` (contagens de substituição podem mudar; conferir que "Claude Code"→"GLM Harness" continua com mesmo comprimento e que as cores do tema não mudaram de valor).
- `vendor/` é git-ignored (231MB); rebuild documentado no README.
- Limpeza pendente autorizada: deletar repo `OpenSource-LLM-on-ClaudeCode` + pasta `..\OS-CC-MCP` (confirmar com o usuário antes, por educação).
- PS 5.1: corpo com acentos quebra Content-Length no Invoke-RestMethod (testes manuais em ASCII).

## Como retomar rápido
- Smoke: `& "C:\Users\ACS Gamer\Documents\vscode-local\CC_Kernel\launcher\glm.ps1" -p "which model are you?"`
- Serviço: `ccr status` / `ccr restart`; config do router: `~/.claude-code-router/config.json`.
- Arquivos-chave: `launcher/glm.ps1`, `launcher/apply-glm-branding.mjs`, `glm-home/CLAUDE.md`, README.
