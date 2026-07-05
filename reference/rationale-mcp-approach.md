# Rationale — why this project exists (and why MCP, not a gateway)

> This is the design note that motivated the repo. In short: on a Claude **Max**
> subscription you want to keep the native session (which preserves the
> subscription), yet offload heavy agentic execution to a free open-source model.
> The only way to do that **without dropping Max** is to expose the open-source
> model as an **MCP tool** the native Claude session calls — never as the
> session's own brain via a gateway. The full argument follows.

---

# Claude (assinatura Max) como gerente + GLM 5.2 como executor — o caminho certo

**Cenário:** você tem a assinatura **Claude Max** e quer mantê-la. O Claude continua sendo o **gerente** (ouve, pensa, delega, avalia) dentro do próprio Claude Code, mas as tarefas pesadas de execução vão para um **subagente/executor rodando GLM 5.2** (via endpoint gratuito da NVIDIA). A assinatura Max subsidia o trabalho; o GLM executa de graça.

Este documento fecha a decisão de arquitetura para esse cenário específico.

---

## A verdade que decide tudo: Max e gateway são mutuamente exclusivos

Manter o **Max** significa que a sessão principal autentica por **OAuth de assinatura**, direto na Anthropic. O **gateway** — que é o *único* jeito de fazer o GLM ser um **subagente nativo de verdade** (o GLM como o *cérebro* do subagente) — exige uma **credencial de gateway** para despachar ao provider do GLM.

**O motivo exato (importante para não errar o diagnóstico):** não é o `ANTHROPIC_BASE_URL` *sozinho* que derruba a assinatura. Segundo a doc oficial, enquanto uma **credencial de gateway** estiver ativa — `ANTHROPIC_AUTH_TOKEN` ou `apiKeyHelper` — "a assinatura claude.ai **não é usada**: a credencial substitui o login e os limites da assinatura não se aplicam". Como servir o GLM da NVIDIA **exige** essa credencial no gateway, o Max cai **de qualquer forma**. (Setar só `ANTHROPIC_BASE_URL` sem credencial preservaria a assinatura, mas isso só serve para tráfego que segue para a própria Anthropic — não resolve rotear para o GLM.)

**Conclusão direta:** se manter o Max é obrigatório, o *"GLM como subagente nativo"* **está fora da mesa**. Não é limitação sua — é como o Claude Code é construído (um único `ANTHROPIC_BASE_URL` para a sessão inteira). Pode largar essa ideia específica.

> Regra de bolso: **Max preservado ⇒ sessão principal 100% nativa ⇒ sem gateway (sem credencial de gateway) ⇒ o GLM entra como ferramenta, não como subagente-cérebro.**

> ⚠️ **Risco adicional que reforça o caminho MCP:** a Anthropic declara **explicitamente que NÃO suporta** rotear o Claude Code para modelos não-Claude através de nenhum gateway. Funciona, mas é território **não suportado** — pode quebrar a cada release do Claude Code (o gateway precisa acompanhar novas capabilities). O caminho MCP (recomendado abaixo) é **suportado** e não sofre desse risco. Mais um motivo para preferir MCP a gateway, além da questão do Max.

---

## O que você PODE ter (e é ótimo): Claude nativo + GLM como *ferramenta agêntica*

Mantendo o Max, a sessão principal fica 100% nativa (Claude, assinatura intacta) e o GLM entra como uma **ferramenta MCP** que o Claude-gerente chama. Funcionalmente é exatamente o que foi pedido:

> **Claude ouve, pensa, delega e avalia; o GLM executa (edita, cria, deleta arquivos, roda comandos); a assinatura subsidia.**

O GLM continua sendo **agente de verdade** — lê, escreve, edita, deleta, roda `pytest`, lê o erro e se corrige. A diferença é só *onde mora o loop* e *de quem são as mãos*: aqui, o loop mora numa ferramenta MCP, e o Claude-gerente revisa o resultado.

---

## O benefício real, corretamente nomeado: fôlego de cota (não dinheiro)

No Max o custo não é por token — é **cota de uso**. Execução agêntica pesada **queima sua cota rápido**. Jogando a execução no GLM (grátis), você gasta Max **apenas no pensamento de gerência do Claude**. Resultado: sua assinatura **rende muito mais**.

O ganho não é "economizar dólares" — é **esticar o Max**: o Claude para de gastar cota digitando boilerplate e rodando testes, e passa a gastá-la só decidindo, avaliando e conversando com você.

---

## O princípio de design que faz isso valer a pena

A ferramenta GLM tem que ser um **loop agêntico completo por dentro** — não uma edição de tiro único. Assim, **uma única delegação barata do Claude** dispara **um monte de trabalho autônomo do GLM**:

```
Claude (gerente, Max):  "implementa o módulo X com testes"
        │  (1 chamada de ferramenta — barata em cota Max)
        ▼
Ferramenta GLM (MCP):   ┌─ GLM roda 10–15 iterações SOZINHO ──────────┐
                        │  edita → roda pytest → lê erro → corrige …   │  ← tudo no GLM,
                        └─ devolve só o diff/result final ─────────────┘     ZERO cota Max
        │
        ▼
Claude (gerente, Max):  revisa o diff  (1 chamada barata)
```

**Quanto mais agêntica a ferramenta por dentro, mais você offloada por delegação, e menos Max gasta.** Um "loop agêntico que edita/cria/deleta arquivos e roda comandos" é exatamente o que já foi construído e validado neste ambiente (o harness que rodou os 3 projetos de teste do GLM). No caminho do gateway ele seria descartado; **neste caminho (Max + MCP) ele é o coração da solução.**

---

## Recomendação concreta

**Claude nativo (Max) como gerente + GLM exposto como uma ferramenta MCP agêntica.** Duas formas de construir essa ferramenta:

### Opção 1 (recomendada para este caso) — envolver o harness existente num servidor MCP
Expor uma tool tipo `glm_implementar(tarefa, arquivos)` que roda o loop agêntico já pronto internamente e devolve o resultado/diff.

- **Por que esta:** ela já resolve o problema que vai te morder no endpoint grátis da NVIDIA — o **rate limiter de janela deslizante** e o **backoff-com-silêncio-longo** já estão prontos e testados no harness. É só a cola de MCP em cima.
- **Reaproveita** o trabalho já feito (o harness deixa de ser andaime e vira produção).

### Opção 2 — Aider MCP Server (pronto de prateleira)
Máquina de edição robusta e madura; um `claude mcp add` e pronto.

- **Contra:** você teria que **domar o rate limit dos 20/min da NVIDIA por conta própria**. O Aider tem retry, mas **não** a lógica de "silêncio longo" que esse endpoint específico exige (o `429` da NVIDIA é *estendido a cada contato* — retry curto perpetua o bloqueio).

**Entre as duas, para o combo NVIDIA-grátis + Max, prefira a Opção 1** — porque o pedaço mais chato (o rate limit teimoso) já está feito e provado.

---

## Opção extra — a UX literal de "gerente → subagente"

Se você quer a experiência de delegação nativa do Claude Code (o gerente delegando a um subagente, com contexto isolado, tudo dentro do terminal), coloque um **subagente nativo** (ex.: `editor`) na frente, cuja **única ferramenta** é o MCP do GLM.

- **Ganha:** delegação nativa + isolamento de contexto nativo + Max preservado + o trabalho braçal indo pro GLM.
- **Custo:** o "raciocínio" desse subagente ainda é Claude (gasta um pouco de Max) — mas o volume pesado de execução vai pro GLM.

`.claude/agents/editor.md` (esqueleto):

```markdown
---
name: editor
description: Executor de mudanças de código. Delegue aqui; ele terceriza a edição pesada ao GLM via MCP.
tools: <apenas as ferramentas do MCP do GLM>
---
Você é o gerente do executor GLM. Quebre a tarefa em passos, delegue a implementação
à ferramenta GLM, e devolva ao gerente principal um resumo com o diff e o status dos testes.
```

---

## Lembretes técnicos importantes (para não tropeçar)

- **Rate limit da NVIDIA:** a NVIDIA **não publica SLA oficial** de rate limit para esse endpoint. O número **oficioso** citado por staff em fórum é ~40 RPM no free tier (sem garantia, varia por modelo/carga). A **medição empírica** feita neste ambiente para o `z-ai/glm-5.2` foi **~20 requisições por janela deslizante de 60s, sem nenhum header** de rate limit — plausível e consistente com um limite não publicado e dependente de modelo. Além disso, o bloqueio observado é **estendido a cada contato durante o 429** — insistir com tentativas curtas mantém o bloqueio vivo (observado: 41 min presos sondando a cada 30s); a recuperação exige **silêncio total** por 1–2+ min. → **Trate ~20 RPM como o número seguro a respeitar** (não como valor oficial): a ferramenta GLM **precisa** de rate limiter (~12–16 req/min de folga) + backoff com silêncio longo. (Já resolvido no harness.)
- **Tool calling nativo do GLM:** confirmado — ele emite `tool_calls` no formato OpenAI com argumentos estruturados. É pré-requisito para o loop agêntico funcionar, e está OK.
- **Não confie no "N testes passaram" que o GLM relata:** o Claude-gerente deve **rodar/revisar** de fato o que voltou. (No teste, os 121/121 foram verificados manualmente, não só relatados.)
- **Contexto:** o trabalho sujo do GLM (as 15 iterações) fica **dentro da ferramenta**, fora do contexto do Claude — o gerente vê só o resultado. Isso é desejável e ainda poupa contexto/cota.
- **Se usar a "Opção extra" (subagente `editor` nativo):** a resolução do modelo de um subagente segue a ordem oficial **`CLAUDE_CODE_SUBAGENT_MODEL` (env var, prioridade máxima) > `model` da invocação > `model:` do frontmatter > `inherit`**. Ou seja, uma env var pode sobrescrever o que está no frontmatter — atenção para não roteá-lo sem querer. Além disso, houve um **bug real e versionado** (issues #44385 / #43869) em que o `model:` do frontmatter era ignorado e o subagente herdava o modelo do pai. **Confira a versão do seu Claude Code** antes de confiar no roteamento por frontmatter. (No nosso caso o subagente `editor` roda em Claude/`inherit` mesmo — quem executa é o GLM via MCP — então isso é mais um alerta geral do que um bloqueio.)

---

## Resumo da decisão

| Pergunta | Resposta |
|---|---|
| Manter o Max é obrigatório? | Sim → **sem gateway, sessão principal nativa** |
| "GLM como subagente nativo" é possível? | **Não** com Max (exigiria gateway → perde a assinatura) |
| O que fazer então? | Claude nativo (gerente) + **GLM como ferramenta MCP agêntica** |
| Como construir a ferramenta? | **Envolver o harness existente num servidor MCP** (reaproveita o rate-limiter pronto). Alternativa: Aider MCP (mas você trata o rate limit) |
| UX de "gerente → subagente"? | Opcional: subagente nativo `editor` cuja única tool é o MCP do GLM |
| Qual o ganho? | **Fôlego de cota do Max** — o Claude gasta assinatura só pensando; o GLM executa de graça |
| Regra de ouro | A ferramenta GLM deve ser um **agente completo por dentro**: 1 delegação barata do Claude = uma tonelada de trabalho autônomo e gratuito do GLM |

---

### Próximo passo (quando você quiser)
Montar a **Opção 1**: um servidor MCP fino em cima do harness que já existe, expondo uma tool agêntica `glm_implementar(...)`, com o rate-limiter/backoff já embutidos, e (opcionalmente) o subagente `editor` nativo na frente. É um passo relativamente curto, porque o motor agêntico e o tratamento do rate limit já estão prontos e validados.

---

## Verificação (fontes primárias)

As afirmações centrais deste documento foram verificadas contra fontes primárias por uma pesquisa dedicada. **Veredito: substancialmente confirmado.** Os pilares se sustentam — sem roteamento nativo por-subagente para outro provider; gateway necessário para outro provider; credencial de gateway derruba o Max; MCP + restrição de `tools` por subagente é o caminho nativo e **o único que preserva a assinatura Max**.

Fontes:
- Claude Code — Subagents (campos do frontmatter, ordem de resolução do modelo, restrição de tools, MCP por subagente, nesting): https://code.claude.com/docs/en/sub-agents
- Claude Code — LLM gateway (ANTHROPIC_BASE_URL, credencial vs. assinatura, "roteamento a modelos não-Claude não é suportado"): https://code.claude.com/docs/en/llm-gateway
- LiteLLM — Anthropic unified `/v1/messages` + aliases + rpm/tpm por modelo: https://docs.litellm.ai/docs/anthropic_unified/ · https://docs.litellm.ai/docs/proxy/dynamic_rate_limit
- claude-code-router (tag `<CCR-SUBAGENT-MODEL>`): https://github.com/musistudio/claude-code-router
- aider-mcp-server (disler) — `aider_ai_code`, `--editor-model`: https://github.com/disler/aider-mcp-server
- NVIDIA NIM free tier rate limit (~40 RPM oficioso, sem SLA): https://forums.developer.nvidia.com/t/request-nvidia-nim-free-tier-rate-limit-increase-40-rpm-severely-limits-agentic-ai-workflows/369762
- Bug de `model:` do subagente ignorado (conferir versão): https://github.com/anthropics/claude-code/issues/44385

> Ajustes já incorporados a partir da verificação: (1) ordem completa de resolução do modelo do subagente + alerta de bug versionado; (2) motivo exato da incompatibilidade Max/gateway (é a **credencial**, não a base URL sozinha); (3) rate limit da NVIDIA apresentado como **medido/oficioso**, não oficial; (4) alerta de que rotear a modelos não-Claude via gateway é território **não suportado** pela Anthropic.
