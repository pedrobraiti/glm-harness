#!/bin/bash
# Notification hook (GLM Harness): makes a notification AUDIBLE + logged.
#
# Why this exists: when Claude Code is waiting on a permission prompt (or idle), the wait is
# SILENT — a tool batch can sit blocked for many minutes and look like "thinking forever" until
# the user happens to check. The model itself can't detect this (it's suspended waiting for a
# tool_result that never comes), so the alert has to come from OUTSIDE the model — here. This
# turns a silent multi-minute stall into an immediate ping. Pure alerting; never blocks anything.

input=$(cat 2>/dev/null)

# Best-effort: pull the notification message from the payload.
message=$(printf '%s' "$input" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//; s/"$//')
[ -z "$message" ] && message="GLM 5.2 needs attention (permission pending or idle wait)."

# Audible: terminal bell now, plus a best-effort Windows beep in the background (non-blocking,
# so the hook returns fast even if powershell is slow/absent).
printf '\a' >&2
powershell.exe -NoProfile -Command "[console]::beep(880,250); [console]::beep(660,300)" >/dev/null 2>&1 &

# Timestamped log so a stall is greppable after the fact (e.g. "did it sit on a permission prompt?").
log="C:/Users/ACS Gamer/Documents/vscode-local/glm-harness/glm-home/hooks/notifications.log"
printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$log" 2>/dev/null

exit 0
