// Statusline do GLM Harness — mostra modelo, uso da janela de contexto e,
// quando relevante, o estado do rate limiter (cooldown de 429 / fila).
//
// O Claude Code envia JSON da sessão via stdin a cada atualização e exibe a
// primeira linha impressa. ANSI é suportado. Precisa ser RÁPIDO: a consulta
// ao limiter tem timeout curto e falha em silêncio.

const PURPLE = '\x1b[38;2;168;85;247m';
const LILAC = '\x1b[38;2;196;141;255m';
const YELLOW = '\x1b[38;2;250;204;21m';
const RED = '\x1b[38;2;248;113;113m';
const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

function contextSegment(data) {
  const ctx = data.context_window || {};
  const pct = Math.min(100, Math.max(0, Math.round(ctx.used_percentage ?? 0)));
  const size = ctx.context_window_size || 200000;
  const used = ctx.total_input_tokens ?? Math.round((pct / 100) * size);

  const filled = Math.round(pct / 10);
  const bar = '▓'.repeat(filled) + '░'.repeat(10 - filled);
  const barColor = pct >= 90 ? RED : pct >= 70 ? YELLOW : LILAC;

  const usedK = Math.round(used / 1000);
  const sizeK = Math.round(size / 1000);
  return `${barColor}${bar}${RESET} ${pct}% ${DIM}(${usedK}k/${sizeK}k)${RESET}`;
}

async function limiterSegment() {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 150);
    const res = await fetch('http://127.0.0.1:3457/glm-limiter/health', { signal: controller.signal });
    clearTimeout(timer);
    const health = await res.json();

    const cooldownMs = (health.cooldownUntil || 0) - Date.now();
    if (cooldownMs > 0) {
      return `${RED}⏸ 429 · retoma em ${Math.ceil(cooldownMs / 1000)}s${RESET}`;
    }
    if (health.queued > 0) {
      return `${YELLOW}fila: ${health.queued}${RESET}`;
    }
    return null; // tudo normal -> statusline limpa
  } catch {
    return null; // limiter fora do ar / lento -> não polui a linha
  }
}

const raw = await readStdin();
let data = {};
try { data = JSON.parse(raw); } catch { /* segue com defaults */ }

const modelName = data.model?.id === 'z-ai/glm-5.2' || data.model?.display_name === 'z-ai/glm-5.2'
  ? 'GLM 5.2'
  : (data.model?.display_name || 'GLM');

const parts = [
  `${PURPLE}◆ ${modelName}${RESET}`,
  contextSegment(data),
];

const limiter = await limiterSegment();
if (limiter) parts.push(limiter);

console.log(parts.join(` ${DIM}│${RESET} `));
