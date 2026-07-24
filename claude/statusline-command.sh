#!/bin/bash
input=$(cat)

# --- Colors (dim-friendly for dark/light terminals) ---
DIM='\033[2m'
RESET='\033[0m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BLUE='\033[34m'
RED='\033[31m'

sep=" ${DIM}|${RESET} "

# --- Core fields ---
model=$(echo "$input" | jq -r '.model.display_name')
dir=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$dir")
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
worktree=$(echo "$input" | jq -r '.worktree.name // empty')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
pr_number=$(echo "$input" | jq -r '.pr.number // empty')
pr_state=$(echo "$input" | jq -r '.pr.review_state // empty')

# --- Git branch (fast, local-only, skip optional locks) ---
branch=""
if git -C "$dir" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

# --- Context usage ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# --- Rate limits (Claude.ai subscription usage, if present) ---
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# --- Session cost / duration / lines changed (not guaranteed on all versions) ---
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

# ===================== Line 1: identity/location =====================
line1="${CYAN}${model}${RESET}"
[ -n "$effort" ] && line1="${line1} ${DIM}(${effort})${RESET}"
line1="${line1}${sep}${GREEN}${dir_name}${RESET}"

if [ -n "$branch" ]; then
  line1="${line1}${sep}${YELLOW}${branch}${RESET}"
fi

if [ -n "$worktree" ]; then
  line1="${line1}${sep}${MAGENTA}wt:${worktree}${RESET}"
fi

if [ -n "$agent_name" ]; then
  line1="${line1}${sep}${MAGENTA}agent:${agent_name}${RESET}"
fi

if [ -n "$pr_number" ]; then
  pr_label="PR#${pr_number}"
  [ -n "$pr_state" ] && pr_label="${pr_label}(${pr_state})"
  line1="${line1}${sep}${BLUE}${pr_label}${RESET}"
fi

if [ -n "$vim_mode" ]; then
  line1="${line1}${sep}${DIM}${vim_mode}${RESET}"
fi

# ===================== Line 2: session/usage stats =====================
line2_parts=()

if [ -n "$used" ] && [ -n "$remaining" ]; then
  used_int=$(printf '%.0f' "$used")
  rem_int=$(printf '%.0f' "$remaining")
  line2_parts+=("${DIM}ctx: ${used_int}% used / ${rem_int}% left${RESET}")
fi

if [ -n "$five_hour" ] || [ -n "$seven_day" ]; then
  rl=""
  if [ -n "$five_hour" ]; then
    rl="5h:$(printf '%.0f' "$five_hour")%"
  fi
  if [ -n "$seven_day" ]; then
    [ -n "$rl" ] && rl="$rl "
    rl="${rl}7d:$(printf '%.0f' "$seven_day")%"
  fi
  line2_parts+=("${DIM}${rl}${RESET}")
fi

if [ -n "$cost_usd" ] && [ "$cost_usd" != "0" ]; then
  line2_parts+=("${DIM}\$$(printf '%.2f' "$cost_usd")${RESET}")
fi

if [ -n "$duration_ms" ] && [ "$duration_ms" != "0" ]; then
  total_sec=$((duration_ms / 1000))
  mins=$((total_sec / 60))
  secs=$((total_sec % 60))
  line2_parts+=("${DIM}${mins}m${secs}s${RESET}")
fi

if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
  la=${lines_added:-0}
  lr=${lines_removed:-0}
  if [ "$la" != "0" ] || [ "$lr" != "0" ]; then
    line2_parts+=("${GREEN}+${la}${RESET}${DIM}/${RESET}${RED}-${lr}${RESET}")
  fi
fi

if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  line2_parts+=("${DIM}style:${output_style}${RESET}")
fi

line2=""
for part in "${line2_parts[@]}"; do
  if [ -z "$line2" ]; then
    line2="$part"
  else
    line2="${line2}${sep}${part}"
  fi
done

if [ -n "$line2" ]; then
  printf '%b\n%b\n' "$line1" "$line2"
else
  printf '%b\n' "$line1"
fi
