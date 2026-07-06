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

// Janela EFETIVA no endpoint gratuito da NVIDIA: ~202k físicos (HTTP 500
// acima disso), então operamos com 180k de margem. O launcher seta a env;
// calculamos a porcentagem por conta própria a partir dos tokens usados.
const WINDOW_SIZE = Number(process.env.GLM_CONTEXT_WINDOW || 180000);

// O router não propaga o usage no modo streaming (chega tudo zerado), então
// quando os tokens oficiais forem 0 estimamos pelo transcript da sessão:
// caracteres de conteúdo / 4 + custo fixo do sistema (system prompt + tools).
const SYSTEM_OVERHEAD_TOKENS = 25000;

async function estimateFromTranscript(transcriptPath) {
  try {
    const { readFile } = await import('node:fs/promises');
    const lines = (await readFile(transcriptPath, 'utf8')).split('\n');
    let chars = 0;
    for (const line of lines) {
      try {
        const content = JSON.parse(line)?.message?.content;
        if (content) chars += JSON.stringify(content).length;
      } catch { /* linha não-JSON */ }
    }
    return chars > 0 ? Math.round(chars / 4) + SYSTEM_OVERHEAD_TOKENS : 0;
  } catch {
    return 0;
  }
}

function formatTokens(tokens) {
  if (tokens >= 1000000) return `${(tokens / 1000000).toFixed(1).replace('.0', '')}M`;
  return `${Math.round(tokens / 1000)}k`;
}

async function contextSegment(data) {
  const ctx = data.context_window || {};
  const reportedSize = ctx.context_window_size || 200000;
  let used = ctx.total_input_tokens
    ?? Math.round(((ctx.used_percentage ?? 0) / 100) * reportedSize);
  let estimated = false;

  if (!used && data.transcript_path) {
    used = await estimateFromTranscript(data.transcript_path);
    estimated = used > 0;
  }

  const pct = Math.min(100, Math.max(0, Math.round((used / WINDOW_SIZE) * 100)));
  const filled = Math.round(pct / 10);
  const bar = '▓'.repeat(filled) + '░'.repeat(10 - filled);
  const barColor = pct >= 90 ? RED : pct >= 70 ? YELLOW : LILAC;
  const tilde = estimated ? '~' : '';

  return `${barColor}${bar}${RESET} ${tilde}${pct}% ${DIM}(${tilde}${formatTokens(used)}/${formatTokens(WINDOW_SIZE)})${RESET}`;
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
    const rpd = health.rpd;
    if (rpd?.budget > 0 && rpd.used >= rpd.budget) {
      const mins = Math.max(1, Math.ceil((rpd.oldestFreesInSeconds || 0) / 60));
      return `${RED}⏸ cota diária ${rpd.used}/${rpd.budget} · abre em ~${mins}min${RESET}`;
    }
    if (health.queued > 0) {
      return `${YELLOW}fila: ${health.queued}${RESET}`;
    }
    // Medidor de cota diária: aparece a partir de 50% (amarelo a partir de 80%).
    if (rpd?.budget > 0 && rpd.used >= rpd.budget * 0.5) {
      const color = rpd.used >= rpd.budget * 0.8 ? YELLOW : DIM;
      return `${color}▮ ${rpd.used}/${rpd.budget} req/dia${RESET}`;
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
  await contextSegment(data),
];

const limiter = await limiterSegment();
if (limiter) parts.push(limiter);

console.log(parts.join(` ${DIM}│${RESET} `));
