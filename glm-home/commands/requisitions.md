---
description: Ver ou ajustar o limite de requisições do GLM Harness (rate limiter local)
argument-hint: [maxConcurrent] [cooldownSeconds]
---

O rate limiter do GLM Harness (proxy local na porta 3457) controla quantas requisições suas chegam simultaneamente ao endpoint da NVIDIA e o que acontece num 429. A config vive em:

`C:\Users\ACS Gamer\Documents\vscode-local\CC_Kernel\limiter-config.json`

Campos:
- `maxConcurrent` — requisições simultâneas em voo (free tier da NVIDIA aguenta ~2; use 1 se estiver tomando 429).
- `cooldownSeconds` — pausa em silêncio total após um 429, antes de retomar sozinho (o bloqueio da NVIDIA se ESTENDE a cada contato — não diminua demais).
- `maxAttempts` — tentativas por requisição antes de desistir.

A config tem **hot-reload**: o limiter relê o arquivo a cada decisão — editar o JSON já vale, sem reiniciar nada.

Sua tarefa com os argumentos recebidos ($ARGUMENTS):
1. **Sem argumentos:** leia o `limiter-config.json`, mostre os valores atuais e o estado vivo do limiter (`Invoke-RestMethod http://127.0.0.1:3457/glm-limiter/health` — mostra fila e cooldown ativo), e explique brevemente cada campo.
2. **Um número (ex.: `/requisitions 1`):** atualize `maxConcurrent` para esse valor no JSON.
3. **Dois números (ex.: `/requisitions 1 90`):** atualize `maxConcurrent` e `cooldownSeconds`.
4. Confirme o que mudou mostrando o JSON final. Não reinicie nenhum serviço — o hot-reload cuida disso.
