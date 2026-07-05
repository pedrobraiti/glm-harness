# Handoff — de onde parei

> **Propósito:** este arquivo serve para que um chat NOVO saiba com precisão "de onde eu parei",
> de forma relativamente detalhada. É o PRIMEIRO arquivo que a próxima sessão lê.
> Mantenha-o vivo e específico — detalhado o bastante para retomar sem reconstruir o raciocínio.

**Última atualização:** 2026-07-05 (entrega do núcleo completo: glm funcional + branding)

## Onde parei
**Projeto entregue e funcional.** `glm -p` responde como GLM 5.2 via router→NVIDIA, com o binário patchado "GLM Harness" (roxo). Tudo commitado e pushado em `pedrobraiti/glm-harness` (privado). O que falta é só validação visual interativa pelo usuário (abrir `glm` num terminal de verdade e ver o banner roxo/"GLM Harness") e observar o comportamento do free tier da NVIDIA sob rajadas de uma sessão interativa real.

## Contexto mental
Cadeia completa: `glm` (função no $PROFILE / glm.cmd no npm dir) → `launcher/glm.ps1` (env por-processo: BASE_URL=router:3456, AUTH_TOKEN, MODEL=z-ai/glm-5.2, MAX_THINKING_TOKENS=0, CLAUDE_CONFIG_DIR=glm-home) → `vendor/glm-claude.exe` (Claude Code 2.1.200 npm vendorado, patchado por `launcher/apply-glm-branding.mjs`: "Claude Code"→"GLM Harness" 906x, laranja rgb(215,119,87)→roxo rgb(168,85,247) 9x incl. `clawd_body` do mascote, shimmers 2x+2x — sempre bytes de mesmo comprimento) → claude-code-router 2.0.0 (config `~/.claude-code-router/config.json`, provider nvidia) → `integrate.api.nvidia.com` z-ai/glm-5.2.

Decisões/aprendizados importantes: (1) o pacote npm ≥2.1.x é só wrapper de binário nativo — o patch é binário, não em cli.js; (2) sem ANTHROPIC_MODEL o GLM se apresentava como "Claude Fable 5" (obedecia ao system prompt); (3) roteamento provado por falsificação (porta morta → ConnectionRefused), pois o log do ccr fica vazio; (4) 400 `reasoning` da NVIDIA resolvido desligando thinking no cliente (GLM já pensa em max no servidor).

## Próximo passo concreto
Pedir ao usuário para abrir `glm` num terminal novo (o $PROFILE precisa ser recarregado: novo terminal ou `. $PROFILE`) e confirmar: banner "GLM Harness" roxo, mascote roxo, sessão respondendo como GLM. Depois, uso real para calibrar o quanto o limite de concorrência ~2 da NVIDIA incomoda.

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
