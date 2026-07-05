# Decisões arquiteturais/técnicas

Registro de decisões com o "porquê". Append-only — não edita entradas antigas.

## 2026-07-04 — Caminho B (NVIDIA grátis + claude-code-router), não z.ai pago
**Motivo:** o usuário indicou explicitamente "do jeito que pega da NVIDIA" — usar a chave gratuita já existente. O proxy de tradução não foi escrito do zero: usamos o `claude-code-router` (musistudio, v2.0.0), conforme recomendação do planejamento.
**Alternativas consideradas:** Caminho A (endpoint Anthropic-nativo pago da z.ai) — mais robusto, sem proxy, mas pago; fica como upgrade futuro se o free tier da NVIDIA sufocar no uso real.

## 2026-07-04 — Launcher seta env vars direto e chama `claude` (não usa `ccr code`)
**Motivo:** controle explícito do escopo por-processo (`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` só no processo do `glm`) e para evitar a reconstrução de argumentos do `ccr code` (minimist + shell:true), que pode mangolar flags. O launcher garante o serviço do router de pé e repassa `@args` verbatim ao `claude`.
**Alternativas consideradas:** `ccr code @args` — funciona, mas menos controle sobre env e args.

## 2026-07-05 — Rate limiter próprio (proxy fino) em vez de retry do cliente ou do router
**Motivo:** o 429 da NVIDIA se ESTENDE a cada contato, então retry curto (padrão de qualquer cliente) perpetua o bloqueio. Um proxy fino entre o Claude Code e o router dá o comportamento certo: fila com concorrência limitada + ao primeiro 429, silêncio TOTAL de todo o tráfego por `cooldownSeconds`, retomando sozinho — a sessão só vê uma resposta demorada (com `API_TIMEOUT_MS=600000` no cliente). Config hot-reload (`limiter-config.json`) para o comando `/requisitions` ajustar sem reiniciar. Pedido do usuário: "trava como um ctrl-C e continua sozinho" — a fila entrega isso de forma mais limpa que cancelar+reinjetar "continue".
**Alternativas consideradas:** cancelar a requisição e mandar "continue" depois (mais complexo e com perda de contexto do turno); rate-limit do LiteLLM (rejeita em vez de enfileirar); plugin do ccr (API não documentada).

## 2026-07-05 — Branding via patch binário de mesmo comprimento no exe vendorado
**Motivo:** o pacote npm do Claude Code ≥2.1.x é só um wrapper do binário nativo (não existe mais `cli.js` patchável). Substituições byte-a-byte de mesmo comprimento não deslocam offsets do executável: `"Claude Code"`(11)→`"GLM Harness"`(11), `rgb(215,119,87)`→`rgb(168,85,247)` (roxo #A855F7, inclusive `clawd_body` — o mascote). Script reprodutível `launcher/apply-glm-branding.mjs` gera `vendor/glm-claude.exe`; o `claude` global do Max nunca é tocado.
**Alternativas consideradas:** patchar o exe nativo global (afetaria o Max — descartado); usar versão npm antiga com cli.js (perderia features e divergiria da versão atual); não fazer branding (pedido explícito do usuário).

## 2026-07-05 — Home próprio do glm via CLAUDE_CONFIG_DIR (`glm-home/`)
**Motivo:** o usuário pediu que o GLM "saiba onde estão as próprias configurações". Um home separado dá ao glm memória global própria (`glm-home/CLAUDE.md` com identidade + mapa de autoconfiguração), settings e histórico isolados do `~/.claude` do Max, e elimina o warning de connectors da conta logada.
**Alternativas consideradas:** `--append-system-prompt` no launcher (não persiste em todos os fluxos); escrever no `~/.claude/CLAUDE.md` global (vazaria instruções do GLM pras sessões Claude/Max).

## 2026-07-04 — Chave da NVIDIA vive na config do router; `.env` do projeto é espelho
**Motivo:** o claude-code-router lê a chave de `~/.claude-code-router/config.json` (fora do repo). O `.env` do projeto guarda a mesma chave como fonte de rebuild, git-ignored, espelhado em `.env.example`.
**Alternativas consideradas:** interpolação `$NVIDIA_API_KEY` na config do router — depende do env do processo do serviço (frágil quando o serviço sobe fora do shell do usuário).
