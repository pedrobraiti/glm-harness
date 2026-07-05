#!/bin/bash
# Stop hook: só age em projetos com .claude/ inicializado via /setup.
# Idempotente e sensível a conteúdo: só dispara quando o working tree muda de verdade.

# Lê o JSON que o Claude Code envia no stdin (contexto da sessão).
input=$(cat 2>/dev/null)

# stop_hook_active=true significa que este Stop já é consequência de um hook anterior
# que segurou o encerramento. É o mecanismo oficial anti-loop: não bloqueia de novo.
if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
    exit 0
fi

# Só atua em projeto inicializado via /setup (tem .claude/ e é repo git).
if [ ! -d ".claude" ]; then
    exit 0
fi
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

marker=".claude/.last-stop-signature"

# Mudanças pendentes IGNORANDO o próprio marcador — robusto mesmo se ele não estiver
# no .gitignore (senão o marcador entraria no porcelain e causaria disparo duplo).
pending=$(git status --porcelain | grep -v '\.last-stop-signature')
if [ -z "$pending" ]; then
    # Nada real pendente — limpa marcador pra próxima sujeira disparar de novo.
    rm -f "$marker" 2>/dev/null
    exit 0
fi

# Assinatura SENSÍVEL A CONTEÚDO: conjunto de arquivos (porcelain) + diff do que é rastreado.
# Assim, re-editar um arquivo já sujo também muda a assinatura e re-dispara o lembrete.
# git hash-object só depende do git (já garantido) — sem sha1sum/awk.
head_ref=$(git rev-parse HEAD 2>/dev/null || echo "no-head")
content_hash=$( { git status --porcelain | grep -v '\.last-stop-signature'; git diff HEAD 2>/dev/null; } | git hash-object --stdin )
current_signature="${head_ref}:${content_hash}"

if [ -f "$marker" ]; then
    last_signature=$(cat "$marker")
    if [ "$last_signature" = "$current_signature" ]; then
        # Nada mudou desde o último lembrete — sai silencioso.
        exit 0
    fi
fi

# Estado mudou (ou primeiro disparo) — grava assinatura e injeta lembrete.
echo "$current_signature" > "$marker"

changed_files=$(git status --short | grep -v '\.last-stop-signature')

cat >&2 <<EOF
[memory-hook] Há mudanças não-commitadas neste projeto (.claude/ ativo). Antes de encerrar o turno, avalie:

Arquivos alterados:
$changed_files

1. ATUALIZE .claude/handoff.md com "de onde parei" (onde parou, contexto mental, próximo passo, em aberto)
   — é o PRIMEIRO arquivo que o próximo chat lê para retomar. Detalhado o suficiente, sem reconstruir o raciocínio.
2. Isso fecha uma subtarefa do TODO? Se SIM, commita agora (conventional commits, sem Co-Authored-By).
3. Se é trabalho intermediário, confirme em uma linha e encerre — este lembrete NÃO repete até o estado mudar.
4. Antes de commitar (se for o caso), atualize no MESMO commit o que mudou:
   - .claude/handoff.md (de onde parei — detalhado)
   - .claude/todo.md (marcar subtarefa como [x])
   - .claude/context.md (estado atual mudou?)
   - .claude/decisions.md (decisão arquitetural nova?)
   - README.md (mudou stack, deps, como rodar?)
   - .env.example (mudou alguma chave em .env?)
EOF
exit 2
