# Handoff — de onde parei

> **Propósito:** este arquivo serve para que um chat NOVO saiba com precisão "de onde eu parei",
> de forma relativamente detalhada. É o PRIMEIRO arquivo que a próxima sessão lê.
> Mantenha-o vivo e específico — detalhado o bastante para retomar sem reconstruir o raciocínio.

**Última atualização:** 2026-07-04 (núcleo funcional validado; iniciando branding)

## Onde parei
O `glm` está **funcional ponta a ponta**: `glm -p "which model are you?"` → "I'm GLM 5.2 (z-ai/glm-5.2), running through the Claude Code harness via the glm command". Pipeline: `glm.ps1` (env por-processo) → claude-code-router 2.0.0 (porta 3456, config `~/.claude-code-router/config.json`) → NVIDIA `z-ai/glm-5.2`. Home próprio em `glm-home/` (CLAUDE_CONFIG_DIR) com CLAUDE.md de identidade que ensina o GLM onde vivem as próprias configurações (pedido explícito do usuário).

## Contexto mental
- O 400 `Unsupported parameter(s): reasoning` foi resolvido com `MAX_THINKING_TOKENS=0` + `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` no launcher (GLM já pensa em `max` por default no servidor; nada se perde).
- Isolamento do Max provado: claude com BASE_URL numa porta morta → ConnectionRefused (env honrado por-processo); `claude` sem as vars nem enxerga o router.
- Sem `ANTHROPIC_MODEL`, o GLM se apresentava como "Claude Fable 5" (obedecia o system prompt). Com `ANTHROPIC_MODEL=z-ai/glm-5.2` + o CLAUDE.md de identidade no glm-home, ele se reconhece.
- PS 5.1: `Invoke-RestMethod` com acentos quebra Content-Length → testes manuais com corpo ASCII.

## Próximo passo concreto
**Branding GLM (tarefa em progresso):** vendorar uma cópia local do `@anthropic-ai/claude-code@2.1.200` (ex.: `npm install --prefix vendor @anthropic-ai/claude-code@2.1.200`), patchar no `cli.js` da cópia: cor laranja da marca (#D97757 e variantes) → roxo, e o wordmark/banner "Claude Code" → "GLM Code" (só strings visuais — NÃO tocar em strings funcionais tipo User-Agent/headers/paths sem avaliar). Depois apontar o `glm.ps1` pra cópia patchada (`node vendor\node_modules\@anthropic-ai\claude-code\cli.js @args`) em vez do `claude` global. O `claude` global do Max fica intocado. Criar script de patch reprodutível (ex.: `launcher/apply-glm-branding.ps1`) em vez de editar na mão, pra sobreviver a re-instalações.

## Em aberto / armadilhas
- Free tier NVIDIA: ~2 requisições concorrentes; 429 estende a cada contato. Não fazer rajadas nem paralelismo agressivo em testes.
- `ccr start` roda em foreground; o launcher sobe via `Start-Process` oculto e espera a porta responder.
- Log do router (`~/.claude-code-router/logs/`) ficou vazio mesmo com LOG:true — verificação de roteamento foi feita por falsificação (porta morta), não por log.
- Teste interativo real (UI de terminal) ainda não foi feito — só `-p`. Observar se rajadas da sessão interativa tomam 429.
- README ainda é o do planejamento — reescrever com o uso real (tarefa pendente).

## Como retomar rápido
- `ccr status` (serviço), função `glm` no `$PROFILE`, `glm.cmd` em `%APPDATA%\npm`.
- Smoke: `& "CC_Kernel\launcher\glm.ps1" -p "which model are you?"`.
- Arquivos-chave: `launcher/glm.ps1`, `glm-home/CLAUDE.md`, `~/.claude-code-router/config.json`, docs `01`–`03`.
