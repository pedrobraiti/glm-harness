---
description: Login do harness — configura ou troca a chave de API da NVIDIA
allowed-tools: Bash, Read
---

O usuário quer configurar ou trocar a chave NVIDIA do harness (o "login" deste ambiente — aqui não existe login Anthropic; a credencial é a chave `nvapi-` do build.nvidia.com).

Fluxo:

1. Abra a página de chaves no navegador dele:
   ```
   powershell -NoProfile -Command "Start-Process 'https://build.nvidia.com/settings/api-keys'"
   ```
   Se ele já estiver logado na NVIDIA, cai direto na página da chave; senão o site pede login e volta para lá. Sem conta, dá para criar grátis ali mesmo.

2. Peça para ele colar aqui no chat a chave (começa com `nvapi-`).

3. Com a chave em mãos, rode o instalador:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\ACS Gamer\Documents\vscode-local\glm-harness\launcher\glm-login.ps1" -ApiKey "nvapi-COLADA-AQUI"
   ```
   O script valida a chave na NVIDIA, grava o `.env`, atualiza a config do claude-code-router e reinicia o router se estiver de pé.

4. Relate o resultado. Interpretação dos desfechos do script: chave recusada (401/403) = chave errada, peça de novo; "throttled"/429 = chave VÁLIDA (free tier em rate limit, normal); erro de rede = ofereça tentar de novo.

Não grave a chave em nenhum lugar além dos que o script já grava (.env e config do router).
