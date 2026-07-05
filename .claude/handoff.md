# Handoff — de onde parei

> **Propósito:** este arquivo serve para que um chat NOVO saiba com precisão "de onde eu parei",
> de forma relativamente detalhada. É o PRIMEIRO arquivo que a próxima sessão lê.
> Mantenha-o vivo e específico — detalhado o bastante para retomar sem reconstruir o raciocínio.

**Última atualização:** 2026-07-04 (durante /setup, no meio da implementação)

## Onde parei
Infra montada e validada até o router: claude-code-router 2.0.0 instalado, config em `~/.claude-code-router/config.json` (provider `nvidia` → `z-ai/glm-5.2`, Router todo apontando pro GLM), serviço de pé na porta 3456, e uma requisição Anthropic-format manual retornou resposta real do GLM. Launcher `launcher/glm.ps1` criado, exposto como função `glm` no `$PROFILE` e `glm.cmd` em `%APPDATA%\npm`.

## Contexto mental
O primeiro smoke test do launcher completo (`glm.ps1 -p "..."`) falhou com **400 da NVIDIA: `Unsupported parameter(s): reasoning`** — o Claude Code envia `thinking` e o router traduz para `reasoning`, que o endpoint da NVIDIA rejeita (consistente com o `enable_thinking` rejeitado em `03-FINDINGS.md`). O GLM 5.2 já pensa em `max` por default, então desligar o thinking do lado do Claude Code não perde qualidade. Próxima tentativa: `MAX_THINKING_TOKENS=0` e/ou `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` no `glm.ps1`; se não bastar, procurar transformer do ccr que remova o campo.

## Próximo passo concreto
Adicionar `MAX_THINKING_TOKENS=0` (e se preciso `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`) ao `launcher/glm.ps1` e repetir `& glm.ps1 -p "which model are you?"` até responder GLM sem 400.

## Em aberto / armadilhas
- Pedido do usuário: branding visual — cópia local do Claude Code com tema roxo e "GLM" no lugar de "Claude" (patch no bundle; não tocar no `claude` global do Max). Ainda não iniciado.
- PowerShell 5.1 + `Invoke-RestMethod` com acentos → erro de Content-Length (usar corpo ASCII em testes manuais).
- `ccr start` roda em foreground; o launcher sobe via `Start-Process` oculto.
- Free tier NVIDIA: ~2 requisições concorrentes; 429 estende a cada contato. Não fazer rajadas de teste.

## Como retomar rápido
- Arquivos: `launcher/glm.ps1`, `~/.claude-code-router/config.json`, docs `01`–`03`.
- Comandos: `ccr status` (serviço), `& "...\launcher\glm.ps1" -p "test"` (smoke), função `glm` já no `$PROFILE`.
