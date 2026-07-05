# CC_Kernel

**Objetivo do projeto:** criar um comando de terminal **`glm`** que abre a experiência do **Claude Code**, porém rodando o cérebro do **GLM 5.2** (open-source) — enquanto o comando `claude` normal continua sendo a Claude na sua assinatura **Max**, intacta. Dois comandos, dois cérebros, sem conflito.

> Este é um **recomeço**. Antes existiu um experimento (`OS-CC-MCP`) que expunha o GLM como *ferramenta MCP* dentro de uma sessão Claude/Max. Funcionava, mas a UX não agradou. Agora a direção é outra: um **launcher** que troca o modelo da sessão inteira via variáveis de ambiente (abordagem "gateway"), isolado no processo do `glm`.

---

## 📖 Se você é um chat novo começando aqui, leia nesta ordem:

1. **[`01-BRIEFING.md`](01-BRIEFING.md)** — a história completa: o que já fizemos, o que foi decidido, o que o usuário quer, e o insight-chave que torna isso possível sem perder o Max.
2. **[`02-ARCHITECTURE-AND-PLAN.md`](02-ARCHITECTURE-AND-PLAN.md)** — como o Claude Code roteia a um modelo custom, os dois caminhos possíveis, os gotchas (com env vars **já verificadas**), e o plano de implementação.
3. **[`03-FINDINGS.md`](03-FINDINGS.md)** — achados técnicos concretos medidos/verificados (limite real da NVIDIA, params de thinking do GLM, qualidade do GLM 5.2). Não repita os testes; parta daqui.
4. **[`reference/rationale-mcp-approach.md`](reference/rationale-mcp-approach.md)** — o documento-fonte original (por que MCP preserva o Max, por que gateway derruba). Contexto histórico; a abordagem gateway dele é justamente a que vamos usar agora, com a ressalva do Max já resolvida (ver briefing).

## Status

**Planejamento.** Nada foi construído ainda. As decisões abertas estão no fim do `02-ARCHITECTURE-AND-PLAN.md`.

## Regras de ambiente (do usuário)

- Máquina Windows 11 / PowerShell. Projetos locais vivem em `C:\Users\ACS Gamer\Documents\vscode-local\`.
- Python 3.12+ com `.venv` por projeto; segredos em `.env` (nunca commitado), espelhado em `.env.example`.
- Conventional Commits, sem `Co-Authored-By: Claude`.
- A chave da NVIDIA (pro GLM grátis) está em `..\GLM-5.2-NVDA\.env` — reutilizável, **não** foi colada em nenhum doc.
