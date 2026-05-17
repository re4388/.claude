#!/bin/bash
#
# Static Claude Code statusline — zero dependencies (bash + git + jq only)
# Reads JSON from stdin (Claude Code pipes session state on each refresh).
#

# Read all stdin lines (Claude Code may send multiple JSON objects per batch)
# We take the LAST one as the most recent session state.
input=$(cat)
json=$(echo "$input" | tail -1)

# --- Parse fields from JSON ---
cwd=$(echo "$json" | jq -r '.cwd // .workspace.current_dir // ""')
used_pct=$(echo "$json" | jq -r '.context_window.used_percentage // "?"')
model=$(echo "$json" | jq -r '.model.display_name // .model.id // "?"')

# --- Git branch (only if cwd is in a git repo) ---
branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch=$(cd "$cwd" 2>/dev/null && git branch --show-current 2>/dev/null)
fi

# --- Skills ---
# ccstatusline writes skills to: ~/.claude/projects/<santized-cwd>/skills/<session_id>.json
# But for a simpler approach, check if any .claude/skills/ dir exists in project
skills=""
session_id=$(echo "$json" | jq -r '.session_id // ""')
project_dir=$(echo "$json" | jq -r '.workspace.project_dir // ""')
if [ -n "$session_id" ] && [ -n "$project_dir" ]; then
  # Try ccstatusline's skills file format
  sanitized=$(echo "$project_dir" | tr '/' '-')
  skills_file="$HOME/.claude/projects/${sanitized}/skills/${session_id}.json"
  if [ -f "$skills_file" ]; then
    skills=$(jq -r 'join(",")' "$skills_file" 2>/dev/null)
  fi
fi
# Fallback: check project .claude/skills/ directory
if [ -z "$skills" ] && [ -n "$project_dir" ]; then
  skills_dir="$project_dir/.claude/skills"
  if [ -d "$skills_dir" ]; then
    skills=$(ls "$skills_dir" 2>/dev/null | sed 's/\.[^.]*$//' | tr '\n' ',' | sed 's/,$//')
  fi
fi

# --- Assemble statusline ---
parts=()

# Current path (shortened: show last 2 dirs)
if [ -n "$cwd" ]; then
  short_path=$(echo "$cwd" | sed 's|^'"$HOME"'|~|' | awk -F/ '{if(NF>2) printf ".../%s/%s", $(NF-1), $NF; else print}')
  parts+=("[$short_path]")
fi

# Git branch
if [ -n "$branch" ]; then
  parts+=("[ $branch]")
fi

# Model
parts+=("[$model]")

# Context usage
if [ "$used_pct" != "null" ] && [ -n "$used_pct" ]; then
  # Color code: green <50, yellow 50-80, red >80
  if [ "$used_pct" -gt 80 ] 2>/dev/null; then
    ctx_color="🔴"
  elif [ "$used_pct" -gt 50 ] 2>/dev/null; then
    ctx_color="🟡"
  else
    ctx_color="🟢"
  fi
  parts+=("[ctx:$used_pct%]")
fi

# Skills
if [ -n "$skills" ]; then
  parts+=("[🧩 $skills]")
fi

# Output
(
  IFS=' '
  echo " ${parts[*]} "
)
