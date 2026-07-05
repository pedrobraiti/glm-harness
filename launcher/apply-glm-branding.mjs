// Gera vendor/glm-claude.exe: cópia do binário do Claude Code com branding GLM.
//
// Regras do patch binário: toda substituição tem EXATAMENTE o mesmo número de
// bytes que o original (offsets do executável não podem mudar).
//
// - "Claude Code" (11) -> "GLM Harness" (11): wordmark/banner/textos de UI.
// - rgb(215,119,87) -> rgb(168,85,247): laranja da marca -> roxo (#A855F7).
//   Inclui `claude:` (destaques) e `clawd_body:` (o mascote fica roxo).
// - Shimmers do laranja -> roxos claros correspondentes.
//
// Uso: node apply-glm-branding.mjs
// Re-rodar após reinstalar/atualizar o pacote vendorado (npm install --prefix vendor).

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, '..', 'vendor', 'node_modules', '@anthropic-ai', 'claude-code-win32-x64', 'claude.exe');
const target = join(here, '..', 'vendor', 'glm-claude.exe');

const REPLACEMENTS = [
  ['Claude Code', 'GLM Harness'],
  ['215,119,87', '168,85,247'],   // claude / clawd_body: laranja -> roxo
  ['245,149,117', '196,141,255'], // claudeShimmer (tema escuro)
  ['235,159,127', '206,161,255'], // claudeShimmer (tema claro/daltonizado)
];

for (const [from, to] of REPLACEMENTS) {
  if (Buffer.byteLength(from) !== Buffer.byteLength(to)) {
    throw new Error(`Tamanhos diferentes: "${from}" (${Buffer.byteLength(from)}) vs "${to}" (${Buffer.byteLength(to)})`);
  }
}

console.log(`Lendo ${source} ...`);
const binary = readFileSync(source);

for (const [from, to] of REPLACEMENTS) {
  const fromBytes = Buffer.from(from, 'ascii');
  const toBytes = Buffer.from(to, 'ascii');
  let count = 0;
  let offset = binary.indexOf(fromBytes);
  while (offset !== -1) {
    toBytes.copy(binary, offset);
    count++;
    offset = binary.indexOf(fromBytes, offset + toBytes.length);
  }
  console.log(`  "${from}" -> "${to}": ${count} substituições`);
}

writeFileSync(target, binary);
console.log(`Gravado ${target}`);
