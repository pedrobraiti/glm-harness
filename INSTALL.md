# Instalação do GLM Harness numa máquina nova

> **Este guia foi escrito para ser executado por uma sessão do Claude Code** (qualquer modelo) na máquina de destino. Humano: clone o repo, abra o Claude Code na pasta clonada e cole: *"Leia o INSTALL.md e instale o GLM Harness nesta máquina, me pedindo só o que depender de mim (como a chave da NVIDIA)."*

## O que é isto

Comando `glm` que abre a experiência completa do Claude Code rodando **GLM 5.2** (grátis, via NVIDIA) como cérebro — com visual roxo/"GLM Harness", memória persistente, skills, hooks e MCPs próprios. O `claude` normal da máquina não é afetado. Detalhes de arquitetura no `README.md`.

## Pré-requisitos

- Windows 10/11 com PowerShell
- **Node.js 18+** (`node --version`)
- **Claude Code** instalado e funcional (`claude --version`) — usado só como bootstrapper e para o Git Bash que o acompanha (os hooks são scripts bash)
- **git** (`git --version`)
- Uma **chave de API da NVIDIA (gratuita)** — ver passo 1

## Passo 1 — Chave da NVIDIA (única coisa que o humano precisa fazer)

1. Acesse **https://build.nvidia.com** e crie uma conta (gratuita).
2. Procure o modelo **`z-ai/glm-5.2`** (ou qualquer modelo) e clique em **"Get API Key"** / **"Generate Key"**.
3. A chave começa com `nvapi-`. Guarde-a.

> Free tier: ~2 requisições simultâneas em voo; bloqueios 429 se estendem a cada contato. O harness já traz um rate limiter que administra isso sozinho.

## Passo 2 — Clonar e configurar segredos

```powershell
git clone https://github.com/pedrobraiti/glm-harness.git
cd glm-harness
Copy-Item .env.example .env
# edite .env e preencha: NVIDIA_API_KEY=nvapi-...
```

## Passo 3 — Adaptar caminhos absolutos (IMPORTANTE)

O repo foi criado em `C:\Users\ACS Gamer\Documents\vscode-local\CC_Kernel`. Faça um **search & replace** desse caminho pelo caminho real do clone nesta máquina, nos arquivos:

- `glm-home\CLAUDE.md` (tabela de autoconfiguração do GLM)
- `glm-home\settings.json` (comandos dos hooks)
- `glm-home\hooks\notify-alert.sh` (caminho do log)

Substitua também o nome de usuário nas referências a `$PROFILE`/`%APPDATA%` se aparecerem.

Além disso, o `glm-home\CLAUDE.md` importa `@rules/ESSENTIALS.md`, que **não vem no clone** (é pessoal por máquina: chaves e preferências do dono). Crie um `glm-home\rules\ESSENTIALS.md` próprio (chaves de API do novo dono, particularidades da máquina — sem nunca commitá-lo; já está no `.gitignore`) ou remova a linha do import.

## Passo 4 — Router (tradutor Anthropic ↔ OpenAI)

```powershell
npm install -g @musistudio/claude-code-router
```

Crie `~\.claude-code-router\config.json` a partir de `reference\ccr-config.template.json`, colando a chave `nvapi-` do `.env` no campo `api_key`.

## Passo 5 — Binário com branding GLM

```powershell
npm install --prefix vendor @anthropic-ai/claude-code@2.1.200
node launcher\apply-glm-branding.mjs
# valida: vendor\glm-claude.exe --version  ->  "2.1.200 (GLM Harness)"
```

> Se a versão 2.1.200 não existir mais no npm, use a mais próxima disponível e confira no log do patch que as substituições ocorreram (contagens > 0). Se alguma cor mudou de valor no update, ajuste os pares em `apply-glm-branding.mjs` (as substituições exigem MESMO comprimento em bytes).

## Passo 6 — Comando `glm` no PATH

**Função no $PROFILE do PowerShell** (crie o arquivo se não existir):

```powershell
# adicione ao $PROFILE (caminho do clone!):
function glm {
    & "<CAMINHO-DO-CLONE>\launcher\glm.ps1" @args
}
```

**E/ou `glm.cmd` num diretório do PATH** (ex.: `%APPDATA%\npm`):

```bat
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<CAMINHO-DO-CLONE>\launcher\glm.ps1" %*
```

## Passo 7 — (Opcional) Sessões compartilhadas com o Claude Code local

Para o `/resume` listar as mesmas conversas no `claude` e no `glm`:

```powershell
Remove-Item -Recurse -Force "<CAMINHO-DO-CLONE>\glm-home\projects" -ErrorAction SilentlyContinue
New-Item -ItemType Junction -Path "<CAMINHO-DO-CLONE>\glm-home\projects" -Target "$HOME\.claude\projects"
```

## Passo 8 — (Opcional) MCPs

O settings do GLM habilita os plugins `github` e `rust-analyzer-lsp`; se a pasta `glm-home\plugins` não existir, copie de `~\.claude\plugins` (ou remova `enabledPlugins` do `glm-home\settings.json`). Para os MCPs serena/context7/playwright, adicione ao `glm-home\.claude.json` (criado no primeiro run) a chave `mcpServers` — exemplos no `README.md`/histórico do repo. **Nada disso é obrigatório para o núcleo funcionar.**

## Passo 9 — Testar

```powershell
# num terminal NOVO (para o $PROFILE recarregar):
glm -p "Em uma linha: qual modelo você é?"
# esperado: resposta se identificando como GLM 5.2
glm    # sessão interativa: banner roxo "GLM Harness"
```

Diagnóstico se falhar:
- `ccr status` — router de pé? (`ccr restart` recarrega a config)
- `Invoke-RestMethod http://127.0.0.1:3457/glm-limiter/health` — limiter de pé?
- `logs\limiter.log` e `logs\limiter-err.log` — erros/cooldowns de 429
- 429 persistente = free tier bloqueado; deixe alguns minutos de silêncio total

## O que NÃO vem no clone (por design)

- **Memórias pessoais** (`glm-home\memory\`) — o launcher cria o índice vazio no primeiro run; o GLM do novo dono constrói a própria memória. Personalize o começo pedindo a ele: *"salve na sua memória global quem eu sou: ..."*
- `vendor\` (binários, 230MB — passo 5 recria), `.env` (passo 2), config do router (passo 4), `logs\`, estado de runtime do `glm-home`.
