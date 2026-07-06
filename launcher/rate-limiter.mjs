// Rate limiter do GLM Harness — proxy fino entre o Claude Code e o
// claude-code-router, feito para o free tier da NVIDIA (~2 requisições em
// voo; o bloqueio 429 se ESTENDE a cada novo contato).
//
// Comportamento:
// - Fila com limite de concorrência (maxConcurrent): o excesso espera, nada
//   é descartado.
// - Ao receber 429 do upstream: pausa TODO o tráfego (silêncio total) por
//   cooldownSeconds e retenta sozinho — a sessão do Claude Code só percebe
//   uma requisição demorada; nenhum "continue" manual é necessário.
// - Config em ../limiter-config.json, hot-reload (lida a cada decisão), então
//   o comando /requisitions ajusta limites sem reiniciar nada.
//
// Uso: node rate-limiter.mjs   (o glm.ps1 sobe isso sozinho)

import http from 'node:http';
import { pipeline } from 'node:stream';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const configPath = join(here, '..', 'limiter-config.json');

const PORT = 3457;
const UPSTREAM = { host: '127.0.0.1', port: 3456 };
const DEFAULTS = { maxConcurrent: 2, cooldownSeconds: 75, maxAttempts: 12 };

function loadConfig() {
  try {
    return { ...DEFAULTS, ...JSON.parse(readFileSync(configPath, 'utf8')) };
  } catch {
    return { ...DEFAULTS };
  }
}

function log(message) {
  console.log(`[limiter ${new Date().toISOString()}] ${message}`);
}

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

// Semáforo com limite relido a cada despacho (hot-reload do maxConcurrent).
let inFlight = 0;
const waiters = [];

function dispatchWaiters() {
  while (inFlight < loadConfig().maxConcurrent && waiters.length > 0) {
    inFlight++;
    waiters.shift()();
  }
}

function acquireSlot() {
  return new Promise(resolve => {
    waiters.push(resolve);
    dispatchWaiters();
  });
}

function releaseSlot() {
  inFlight--;
  dispatchWaiters();
}

// Cooldown global: enquanto ativo, NENHUMA requisição toca o upstream
// (contato durante o 429 estende o bloqueio da NVIDIA).
let cooldownUntil = 0;

// Escalada com MEMÓRIA GLOBAL: 429s consecutivos (de qualquer requisição)
// alongam a espera. Sem isso, cada retry do cliente nascia como requisição
// nova com escalada zerada -> sondas a cada 2-4min -> bloqueio profundo se
// auto-sustentava para sempre. Só um sucesso real zera o contador.
let consecutiveRateLimits = 0;

async function waitCooldown() {
  while (Date.now() < cooldownUntil) {
    await sleep(Math.min(cooldownUntil - Date.now(), 1000));
  }
}

// Folga sobre os 10min de API_TIMEOUT_MS do router: socket mudo além disso é
// upstream pendurado — derruba para nunca segurar um slot para sempre.
const UPSTREAM_SILENCE_TIMEOUT_MS = 900_000;

function forward(req, body, onRequest) {
  return new Promise((resolve, reject) => {
    const upstreamReq = http.request(
      {
        host: UPSTREAM.host,
        port: UPSTREAM.port,
        path: req.url,
        method: req.method,
        headers: { ...req.headers, host: `${UPSTREAM.host}:${UPSTREAM.port}` },
      },
      resolve,
    );
    upstreamReq.on('error', reject);
    upstreamReq.setTimeout(UPSTREAM_SILENCE_TIMEOUT_MS, () =>
      upstreamReq.destroy(new Error('upstream mudo por tempo demais')),
    );
    if (onRequest) onRequest(upstreamReq);
    upstreamReq.end(body);
  });
}

async function readAll(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  return Buffer.concat(chunks);
}

function looksLikeRateLimit(status, bodyText) {
  return status === 429 || /"?429"?|rate.?limit/i.test(bodyText);
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/glm-limiter/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, inFlight, queued: waiters.length, cooldownUntil }));
    return;
  }

  const body = await readAll(req);
  const { maxAttempts } = loadConfig();

  // Se o cliente desistir (Ctrl-C, processo morto), abortamos os retries:
  // requisição órfã re-contactando a NVIDIA só estende o bloqueio 429.
  // Também derrubamos o voo ATUAL: um pipe para cliente morto estanca sem
  // emitir end/close e o slot de concorrência vazaria para sempre (deadlock).
  let clientGone = false;
  let activeUpstreamReq = null;
  res.on('close', () => {
    if (!res.writableEnded) {
      clientGone = true;
      if (activeUpstreamReq) activeUpstreamReq.destroy(new Error('cliente desistiu'));
    }
  });

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    // Adquire o slot SO com o cooldown limpo. Sem a re-checagem, na virada do
    // cooldown mais de uma requisição enfileirada escapava: a primeira tomava
    // 429 e re-armava a janela, mas as seguintes já tinham passado da checagem
    // e tocavam a NVIDIA também — estendendo o bloqueio à toa. Com isso, após
    // um 429 sai exatamente UMA sonda por janela de silêncio.
    for (;;) {
      await waitCooldown();
      if (clientGone) {
        log(`cliente desistiu — abortando retries da requisição (tentativa ${attempt})`);
        return;
      }
      await acquireSlot();
      if (Date.now() >= cooldownUntil) break;
      releaseSlot();
    }
    try {
      const upstreamRes = await forward(req, body, r => { activeUpstreamReq = r; });
      const status = upstreamRes.statusCode;

      if (status === 429 || status >= 500) {
        const errBody = await readAll(upstreamRes);
        const errText = errBody.toString('utf8');
        if (looksLikeRateLimit(status, errText) && attempt < maxAttempts) {
          // Escala pelo contador GLOBAL de 429s seguidos (teto 20x = 30min
          // com base 90s): bloqueio raso resolve rápido; bloqueio profundo
          // ganha janelas de silêncio grandes o bastante para expirar.
          const { cooldownSeconds } = loadConfig();
          consecutiveRateLimits++;
          const escalated = cooldownSeconds * Math.min(consecutiveRateLimits, 20);
          cooldownUntil = Math.max(cooldownUntil, Date.now() + escalated * 1000);
          log(`429/rate-limit do upstream (${consecutiveRateLimits} seguidos; tentativa ${attempt}/${maxAttempts}) -> silêncio total por ${escalated}s, retomo sozinho`);
          continue;
        }
        // Upstream respondeu (ainda que com erro não-429): não está bloqueado.
        consecutiveRateLimits = 0;
        const headers = { ...upstreamRes.headers };
        delete headers['content-length'];
        delete headers['transfer-encoding'];
        res.writeHead(status, headers);
        res.end(errBody);
        return;
      }

      consecutiveRateLimits = 0;
      res.writeHead(status, upstreamRes.headers);
      // pipeline, não pipe manual: o callback dispara SEMPRE (fim ou erro em
      // qualquer ponta), então o finally libera o slot mesmo com cliente morto.
      await new Promise(resolve => pipeline(upstreamRes, res, () => resolve()));
      return;
    } catch (err) {
      if (clientGone) {
        log(`cliente desistiu com requisição em voo — abortada (tentativa ${attempt})`);
        return;
      }
      if (attempt >= maxAttempts) {
        res.writeHead(502, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: { type: 'api_error', message: `glm-limiter: upstream inacessível: ${err.message}` } }));
        return;
      }
      log(`erro de conexão com o router (tentativa ${attempt}/${maxAttempts}): ${err.message}`);
      await sleep(1000);
    } finally {
      releaseSlot();
    }
  }

  res.writeHead(429, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ error: { type: 'rate_limit_error', message: 'glm-limiter: tentativas esgotadas; NVIDIA ainda bloqueando' } }));
});

server.on('error', err => {
  if (err.code === 'EADDRINUSE') {
    log(`porta ${PORT} já em uso — outro limiter rodando. Saindo.`);
    process.exit(0);
  }
  throw err;
});

server.listen(PORT, '127.0.0.1', () => {
  const cfg = loadConfig();
  log(`escutando em http://127.0.0.1:${PORT} -> router :${UPSTREAM.port} (maxConcurrent=${cfg.maxConcurrent}, cooldown=${cfg.cooldownSeconds}s)`);
});
