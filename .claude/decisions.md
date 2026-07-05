# Decisões arquiteturais/técnicas

Registro de decisões com o "porquê". Append-only — não edita entradas antigas.

## 2026-07-04 — Caminho B (NVIDIA grátis + claude-code-router), não z.ai pago
**Motivo:** o usuário indicou explicitamente "do jeito que pega da NVIDIA" — usar a chave gratuita já existente. O proxy de tradução não foi escrito do zero: usamos o `claude-code-router` (musistudio, v2.0.0), conforme recomendação do planejamento.
**Alternativas consideradas:** Caminho A (endpoint Anthropic-nativo pago da z.ai) — mais robusto, sem proxy, mas pago; fica como upgrade futuro se o free tier da NVIDIA sufocar no uso real.

## 2026-07-04 — Launcher seta env vars direto e chama `claude` (não usa `ccr code`)
**Motivo:** controle explícito do escopo por-processo (`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` só no processo do `glm`) e para evitar a reconstrução de argumentos do `ccr code` (minimist + shell:true), que pode mangolar flags. O launcher garante o serviço do router de pé e repassa `@args` verbatim ao `claude`.
**Alternativas consideradas:** `ccr code @args` — funciona, mas menos controle sobre env e args.

## 2026-07-04 — Chave da NVIDIA vive na config do router; `.env` do projeto é espelho
**Motivo:** o claude-code-router lê a chave de `~/.claude-code-router/config.json` (fora do repo). O `.env` do projeto guarda a mesma chave como fonte de rebuild, git-ignored, espelhado em `.env.example`.
**Alternativas consideradas:** interpolação `$NVIDIA_API_KEY` na config do router — depende do env do processo do serviço (frágil quando o serviço sobe fora do shell do usuário).
