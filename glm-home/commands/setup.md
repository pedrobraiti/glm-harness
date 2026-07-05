---
description: Inicializa estrutura de memória e git num projeto novo (.claude/, CLAUDE.md, git init)
---

# /setup — Inicializar projeto com memória persistente

Você vai configurar o projeto atual pra usar o sistema de memória + git disciplinado.

## Passos (execute nesta ordem)

### 1. Verifique o estado atual

- Liste o conteúdo do diretório atual.
- Cheque se já existe `.claude/`, `CLAUDE.md`, `README.md` ou repositório git (`.git/`).
- Se algum já existir, **pergunte ao usuário** antes de sobrescrever. Se ele confirmar, sobrescreve; se não, pula o item.
- Cheque identidade git: rode `git config user.name` e `git config user.email`. Se **qualquer um estiver vazio**, pergunte ao usuário os valores AGORA (antes de qualquer commit) e configure com `git config --global` (ou `--local` se ele preferir só pra este projeto). Não prossiga sem isso.

### 2. Crie `.claude/context.md`

Conteúdo inicial (pergunte ao usuário o nome e descrição do projeto antes):

```markdown
# Contexto do projeto

> Camada **estável** da memória: o que o projeto é e suas características macro. Muda devagar.
> O detalhe volátil de "de onde parei" fica no `handoff.md`; as tarefas, no `todo.md`;
> as decisões com o porquê, no `decisions.md`.

**Nome:** <preencher>
**Descrição:** <uma linha sobre o que o projeto faz>
**Stack:** <linguagem, frameworks principais — pode ficar vazio se ainda não definido>

## Visão geral
<o que o projeto faz e para quem, em 2-4 linhas>

## Fase atual
<marco macro — ex: "setup inicial", "MVP em desenvolvimento", "em produção">

## Restrições e bloqueios de longo prazo
<limitações conhecidas, dependências externas, requisitos não-negociáveis — nada / listar>
```

### 3. Crie `.claude/decisions.md`

```markdown
# Decisões arquiteturais/técnicas

Registro de decisões com o "porquê". Append-only — não edita entradas antigas.

<!-- Formato:
## YYYY-MM-DD — Título curto da decisão
**Motivo:** por que foi decidido assim.
**Alternativas consideradas:** o que ficou de fora e por quê.
-->
```

### 4. Crie `.claude/todo.md`

```markdown
# TODO

Plano vivo do projeto. Tarefas e subtarefas, marcadas conforme concluídas.

## Em progresso
- [ ] <primeira tarefa — será preenchida após planning mode, se o usuário usar>

## Próximas
<vazio por enquanto>

## Concluído
- [x] Setup inicial do projeto
```

### 5. Crie `.claude/handoff.md`

Este arquivo existe com **um propósito único e claro**: fazer com que um chat NOVO consiga responder com precisão **"de onde eu parei?"**, de forma relativamente detalhada. É o **primeiro** arquivo que a próxima sessão lê — o ponteiro mais fresco. Não é um resumo de uma linha; é a narrativa que permite retomar o trabalho sem reconstruir o raciocínio do zero.

```markdown
# Handoff — de onde parei

> **Propósito:** este arquivo serve para que um chat NOVO saiba com precisão "de onde eu parei",
> de forma relativamente detalhada. É o PRIMEIRO arquivo que a próxima sessão lê.
> Mantenha-o vivo e específico — detalhado o bastante para retomar sem reconstruir o raciocínio.

**Última atualização:** <data/hora — preencher ao atualizar>

## Onde parei
<Narrativa do que estava sendo feito agora: em qual tarefa, em qual arquivo, em que ponto exato.>

## Contexto mental
<O raciocínio por trás: o que tentei, o que funcionou e o que falhou, por que escolhi este caminho,
o que ainda estou investigando ou em dúvida.>

## Próximo passo concreto
<A PRIMEIRA coisa a fazer ao retomar — específica e acionável, não genérica.>

## Em aberto / armadilhas
<Decisões pendentes, becos sem saída já descartados, gotchas, partes frágeis a cuidar.>

## Como retomar rápido
<Arquivos relevantes, comandos para rodar/testar, onde olhar primeiro.>
```

### 6. Crie `README.md` esqueleto (só se não existir)

```markdown
# <nome do projeto>

<uma frase sobre o que faz — preencher conforme o projeto evolui>

## Como rodar
<preencher quando houver código executável>

## Stack
<preencher conforme definido>
```

### 7. Crie (ou atualize) o `CLAUDE.md` do projeto

Se já existir, **anexe** a seção abaixo ao final. Se não existir, crie com esse conteúdo:

```markdown
# Instruções para o Claude neste projeto

## Memória persistente

Ao iniciar **qualquer** conversa neste projeto, antes de agir:
1. Leia `.claude/handoff.md` **PRIMEIRO** — é o ponteiro mais fresco: responde "de onde parei" com detalhe.
2. Leia `.claude/context.md` para o estado macro/estável do projeto.
3. Leia `.claude/todo.md` para saber o que está em progresso e o que vem a seguir.
4. Rode `git log --oneline -20` para ver atividade recente.
5. Se a tarefa tocar em área sensível/arquitetural, leia `.claude/decisions.md`.

### Manter o handoff vivo

O `.claude/handoff.md` é o que permite a **próxima sessão começar de onde esta parou**. Trate-o como documento vivo:
- Ao concluir qualquer passo significativo (não só no fim da sessão), atualize-o.
- Escreva com detalhe suficiente para um chat novo retomar sem reconstruir seu raciocínio: onde parou, o contexto mental, o próximo passo concreto e o que está em aberto.
- Atualize a data e **sobrescreva** o conteúdo antigo — ele reflete sempre o ESTADO ATUAL de "onde paramos", não é histórico append-only (esse papel é do git e do `decisions.md`).

## Disciplina do TODO

- O `.claude/todo.md` é **mandatório** e deve sempre refletir a realidade do projeto.
- Ao sair do planning mode (ou após planejar qualquer coisa com o usuário), atualize o TODO com tarefas e subtarefas granulares.
- Marque `[x]` a subtarefa **no mesmo commit** em que ela é concluída.
- Subtarefas devem ser pequenas e modulares — se uma não cabe em um commit, quebra em menores.

## Disciplina de commits

- Sempre que uma subtarefa do TODO for **concluída** (não trabalho intermediário), faça um commit.
- Use **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`, `style:`.
- Mensagens claras, no imperativo, descrevendo o **porquê** quando não óbvio.
- **Nunca** inclua `Co-Authored-By: Claude` nas mensagens de commit.
- Antes de cada commit, avalie e atualize **no mesmo commit** se necessário:
  - `.claude/handoff.md` (de onde parei — detalhado, refletindo o estado atual).
  - `.claude/todo.md` (marcar subtarefa concluída).
  - `.claude/context.md` (estado atual mudou?).
  - `.claude/decisions.md` (houve decisão arquitetural nova?).
  - `README.md` (mudou stack, dependências, forma de rodar?).
  - `.env.example` (adicionou/removeu variável em `.env`? espelha aqui sem valores).

## Arquitetura

Seguir os padrões definidos em `~/.claude/rules/BEST_PRACTICES.md` (código profissional, modular, testável; arquitetura escolhida conforme o projeto).

## Autonomia

Neste projeto você tem autonomia ampliada — use com critério profissional (autonomia controlada, não automática).

### Subagentes
- Delegue buscas amplas e trabalho paralelo a subagentes para manter o contexto principal limpo: `Explore` para varreduras em muitos arquivos, `Plan` para desenhar implementação, `general-purpose` para tarefas multi-etapa.
- Use quando a tarefa exigir varrer bastante código, pesquisar em paralelo ou planejar algo não-trivial. Para tarefas simples, resolva direto.

### Agent crews
- Pode ativar múltiplos agentes em paralelo (agent crews) quando a **complexidade do projeto justificar**: várias frentes independentes, refactor grande, investigação ampla.
- Não use crews para trabalho simples — é custo e ruído desnecessários.

### Skills (find-skills)
- Quando perceber que uma capacidade especializada ajudaria (testing, design, deploy, um framework específico), **pesquise proativamente**: `npx skills find <query>` ou a skill `find-skills`.
- Você pode baixar e instalar skills úteis **sem pedir confirmação**, respeitando estas regras:
  - **Sempre LOCAL ao projeto, NUNCA global.** Instale com o projeto como diretório atual e **sem** o flag `-g`:
    ```bash
    npx skills add <owner/repo> --skill <nome> --copy -y
    ```
    Isso instala em `.claude/skills/` (versionado no git). O `--copy` evita symlink apontando pra fora do repo.
  - **Nunca** use `-g` / `--global`. (A documentação da própria `find-skills` sugere `-g` por padrão — **ignore isso aqui**: neste projeto é sempre local.)
  - Prefira fontes confiáveis (`anthropics`, `vercel-labs`, `microsoft`) e skills com volume de instalações relevante; desconfie de fontes obscuras.
  - Informe no resumo qual skill instalou e por quê — a skill entra no commit junto.
```

### 8. Inicialize git

- Se não existir `.git/`, rode `git init`.
- Crie/atualize `.gitignore` com pelo menos: `.venv/`, `__pycache__/`, `*.pyc`, `.env`, `node_modules/`, `.DS_Store`, `.claude/.last-stop-signature`.
- **Não** adicione `.claude/` inteiro ao `.gitignore` — a memória do projeto deve ser versionada (só o marcador do hook é ignorado).
- Se o usuário tem `.env` mas não tem `.env.example`, crie `.env.example` com as mesmas chaves do `.env` **sem os valores**.
- Crie `.gitattributes` (se não existir) pra normalizar fim de linha — evita ruído CRLF/LF no Windows e diffs falsos entre máquinas:

  ```gitattributes
  # Normaliza fim de linha: LF no repositório e no checkout.
  * text=auto eol=lf
  ```

- Crie `.editorconfig` (se não existir) pra padronizar formatação entre editores:

  ```editorconfig
  root = true

  [*]
  charset = utf-8
  end_of_line = lf
  insert_final_newline = true
  trim_trailing_whitespace = true
  indent_style = space
  indent_size = 4

  [*.{js,jsx,ts,tsx,json,yml,yaml,html,css,scss}]
  indent_size = 2

  [*.md]
  trim_trailing_whitespace = false
  ```

- Faça um commit inicial usando conventional commit: `chore: setup inicial do projeto com estrutura .claude/`.

### 9. GitHub remoto (opcional)

Pergunte ao usuário:
> "Quer que eu crie um repositório privado no GitHub agora via `gh repo create`? (sim/não)"

- Se **sim**: rode `gh repo create <nome> --private --source=. --remote=origin --push`.
- Se **não**: só avise que ele pode fazer manualmente depois com `gh repo create` ou pelo site.

### 10. Confirme ao usuário

Responda com um resumo curto do que foi feito e diga que o projeto está pronto. A partir de agora o hook `Stop` global vai lembrar de commitar/atualizar memória quando houver mudanças não-commitadas.
