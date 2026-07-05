# 01 — Briefing: a história, as decisões e o que queremos

> Leia isto primeiro. Aqui está tudo que aconteceu antes, para você não reconstruir o raciocínio do zero.

## 1. Contexto de uma frase

O usuário tem **Claude Max** e quer usar o **GLM 5.2** (open-source, muito bom em código) como um **segundo cérebro de terminal**, chamado por um comando `glm`, sem sacrificar o `claude`/Max.

## 2. O que já foi feito (e por que foi abandonado)

Antes deste projeto, construímos o **`OS-CC-MCP`** (pasta irmã `..\OS-CC-MCP`, repo público no GitHub):

- Era um **servidor MCP** que embrulhava um harness agêntico do GLM e o expunha como *ferramenta* (`implement`, `consult`, `executor_status`) que a Claude nativa (com Max) chamava para **delegar execução pesada** ao GLM.
- **Funcionou de verdade** (testado ponta-a-ponta: o GLM 5.2 real criou arquivos, rodou testes, se corrigiu; 40 testes unitários; MCP registrado e validado pelo protocolo stdio real).
- **Mas a UX não agradou.** O usuário não gostou da ideia de "os chats da Claude usarem o GLM por baixo como ferramenta". Queria outra coisa: **a experiência do Claude Code inteira rodando GLM**, como um app separado.

Decisão: **abandonar a abordagem MCP** e começar o `glm-harness` do zero. O registro do MCP e o subagente global já foram removidos do ambiente. O repo/pasta antigos podem ser deletados (ver §6).

## 3. O que o usuário quer agora (a visão)

- Um comando **`glm`** no terminal → abre o **Claude Code** rodando o **GLM 5.2** como o cérebro da sessão.
- O comando **`claude`** normal → continua Claude na assinatura **Max**, sem ser afetado.
- Projeto novo, do zero, com **home próprio** nesta pasta `glm-harness`.

## 4. O insight-chave que destrava isso (e por que NÃO perde o Max)

O documento antigo (`reference/rationale-mcp-approach.md`) alertava que "gateway derruba o Max". **Isso é verdade, mas é por-processo, não por-conta.** O usuário percebeu isso corretamente:

- "Derrubar o Max" significa só: **enquanto uma credencial de gateway (`ANTHROPIC_AUTH_TOKEN`/`apiKeyHelper`) está ativa NO AMBIENTE daquele processo**, aquele processo não usa a assinatura — usa o gateway.
- Isso é **escopo de variável de ambiente, por processo** (confirmado com a documentação do Claude Code — ver `02`).
- Logo: um launcher `glm` que seta essas env vars **só no próprio processo** roda GLM; um `claude` iniciado sem elas continua no Max. **Os dois coexistem, isolados. A assinatura não é danificada — apenas não é usada pelo processo `glm`.**

O alerta do doc antigo valia para o caso de querer os dois cérebros **na MESMA sessão** (aí `ANTHROPIC_BASE_URL` é único e não dá). O caso atual (dois comandos separados) **não tem esse problema.**

## 5. O que dá pra reaproveitar do projeto antigo

| Reaproveitável | O quê | Onde |
|---|---|---|
| ✅ Sim | O racional/decisões (por que MCP vs gateway, tabela de decisão) | `reference/rationale-mcp-approach.md` (já copiado pra cá) |
| ✅ Sim | A chave da NVIDIA (pro GLM grátis) | `..\GLM-5.2-NVDA\.env` (não colada aqui) |
| ✅ Sim | Achados empíricos (limite real da NVIDIA, params de thinking do GLM, qualidade) | `03-FINDINGS.md` |
| ❌ Não | O código do servidor MCP / harness Python | arquitetura diferente — não serve pro launcher |

## 6. Pendências de limpeza (autorizadas, mas ainda não executadas)

O usuário autorizou **deletar** o repo GitHub (`pedrobraiti/OpenSource-LLM-on-ClaudeCode`) e a pasta local `..\OS-CC-MCP`, mantendo só o reaproveitável (já salvo aqui). **Ainda não foi feito** — priorizamos escrever este briefing. Confirmar antes de apagar (o rationale e a chave já estão preservados/referenciados, então a deleção é segura).

## 7. Papéis

O usuário conduz e decide; nesta virada ele quer construir **junto** com o assistente (voltou atrás do "não quero que você faça"). Mantenha a postura de par técnico: propor, alertar sobre gotchas, e executar sob intenção explícita.
