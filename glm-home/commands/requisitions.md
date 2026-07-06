---
description: Ver ou ajustar o limite de requisições do GLM Harness (rate limiter local)
argument-hint: [maxConcurrent] [cooldownSeconds] [dailyBudget]
---

O rate limiter do GLM Harness (proxy local na porta 3457) controla quantas requisições suas chegam simultaneamente ao endpoint da NVIDIA e o que acontece num 429. A config vive em:

`C:\Users\ACS Gamer\Documents\vscode-local\glm-harness\limiter-config.json`

Campos:
- `maxConcurrent` — requisições simultâneas em voo (free tier da NVIDIA aguenta ~2; use 1 para operar com folga).
- `cooldownSeconds` — pausa base após um 429; escala exponencialmente (2x a cada 429 seguido, teto 30min) porque o bloqueio da NVIDIA REINICIA a cada contato.
- `maxAttempts` — tentativas por requisição antes de desistir.
- `dailyBudget` — trava local de requisições por 24h móveis (o free tier bloqueia a conta inteira perto de ~1000/dia; default 950 = parar antes da parede). O consumo atual aparece no health (`rpd`) e na statusline a partir de 50%.

A config tem **hot-reload**: o limiter relê o arquivo a cada decisão — editar o JSON já vale, sem reiniciar nada.

Sua tarefa com os argumentos recebidos ($ARGUMENTS):
1. **Sem argumentos:** leia o `limiter-config.json`, mostre os valores atuais e o estado vivo do limiter (`Invoke-RestMethod http://127.0.0.1:3457/glm-limiter/health` — mostra fila e cooldown ativo), e explique brevemente cada campo.
2. **Um número (ex.: `/requisitions 1`):** atualize `maxConcurrent` para esse valor no JSON.
3. **Dois números (ex.: `/requisitions 1 90`):** atualize `maxConcurrent` e `cooldownSeconds`.
3b. **Três números (ex.: `/requisitions 1 90 950`):** atualize também o `dailyBudget`.
4. Confirme o que mudou mostrando o JSON final. Não reinicie nenhum serviço — o hot-reload cuida disso.
