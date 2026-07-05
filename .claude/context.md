# Contexto do projeto

> Camada **estável** da memória: o que o projeto é e suas características macro. Muda devagar.
> O detalhe volátil de "de onde parei" fica no `handoff.md`; as tarefas, no `todo.md`;
> as decisões com o porquê, no `decisions.md`.

**Nome:** CC_Kernel (repo GitHub: `glm-harness`)
**Descrição:** Comando de terminal `glm` que abre o Claude Code inteiro rodando o GLM 5.2 como cérebro da sessão, sem afetar o `claude` normal (assinatura Max).
**Stack:** PowerShell (launcher) + claude-code-router (Node, proxy de tradução Anthropic↔OpenAI) + endpoint NVIDIA (`z-ai/glm-5.2`, free tier).

## Visão geral
Dois comandos, dois cérebros: `claude` continua na assinatura Max (intocada); `glm` seta credencial de gateway **só no próprio processo** e aponta pro claude-code-router local (porta 3456), que traduz Anthropic Messages ↔ OpenAI Chat Completions e despacha pro endpoint da NVIDIA. Inclui customização visual (tema roxo/GLM) via cópia local patchada do Claude Code.

## Fase atual
Implementação inicial — launcher funcional, corrigindo compatibilidade de parâmetros (thinking/reasoning) e aplicando branding GLM.

## Restrições e bloqueios de longo prazo
- Free tier da NVIDIA: concorrência ~2 requisições em voo; 429 estendido a cada contato. Uso interativo pesado pode sufocar (ver `03-FINDINGS.md`).
- Rotear Claude Code a modelo não-Claude é oficialmente não-suportado pela Anthropic → pode quebrar a cada update do Claude Code. Pinar/observar versão.
- NVIDIA rejeita parâmetros de thinking não suportados (`enable_thinking`, `reasoning`) → o launcher precisa impedir que o Claude Code os envie.
