#!/usr/bin/env bash
# codex-pane.sh — manage the persistent Codex tmux pane.
#
# Panes created by this script are tagged with tmux pane-local user options
# (@cwc_role / @cwc_repo), so discovery is exact: no screen-text guessing,
# no cross-repo mixups, safe with any number of concurrent agents.
#
# Usage:
#   codex-pane.sh ensure  [--repo DIR] [--model M] [--effort E]   # find-or-launch; prints pane id
#   codex-pane.sh send    <pane> <message>                        # clear composer, send text + Enter, verify submitted
#   codex-pane.sh wait    <pane> [--timeout SECS]                 # block until DONE / NEEDS_INPUT / TIMEOUT
#   codex-pane.sh capture <pane> [--lines N]                      # print pane contents incl. scrollback
#   codex-pane.sh cleanup <pane>                                  # kill a pane this script launched
#
# Exit codes for `wait`: 0 = reply finished (DONE) · 2 = Codex is showing an
# interactive prompt that needs a human/agent decision (NEEDS_INPUT) ·
# 3 = timeout. `send`/`ensure` exit non-zero on failure.
#
# Limitation (by design): one collaboration channel per repo checkout. Run
# concurrent sessions on the same repo from separate git worktrees.

set -u

SESSION="codex-collab"
POLL=5              # seconds between polls
STABLE_POLLS=3      # consecutive identical captures required for DONE

die() { echo "codex-pane: $*" >&2; exit 1; }

hash_capture() { tmux capture-pane -t "$1" -p 2>/dev/null | cksum; }

repo_root() {
  local d="${1:-$PWD}"
  git -C "$d" rev-parse --show-toplevel 2>/dev/null || (cd "$d" && pwd -P)
}

pane_alive() { tmux display-message -t "$1" -p '#{pane_id}' >/dev/null 2>&1; }

# Screen-text signature is a liveness check only — identity comes from tags.
looks_like_codex() {
  tmux capture-pane -t "$1" -p 2>/dev/null \
    | grep -qiE 'Context [0-9]+% left|esc to interrupt|Worked for|OpenAI Codex|Do you trust'
}

find_tagged() { # $1 = repo root → prints pane id or nothing
  tmux list-panes -a -F '#{pane_id}|#{@cwc_role}|#{@cwc_repo}' 2>/dev/null \
    | awk -F'|' -v repo="$1" '$2=="codex" && $3==repo {print $1; exit}'
}

needs_input() { # interactive prompts that must never be mistaken for "done"
  tmux capture-pane -t "$1" -p 2>/dev/null | grep -qiE \
    'Do you trust|Press enter to continue|Allow .*\?|approval|login to|sign in|Select an option|verification code'
}

working() {
  tmux capture-pane -t "$1" -p 2>/dev/null \
    | grep -qiE 'esc to interrupt|Messages to be submitted'
}

idle_prompt() {
  tmux capture-pane -t "$1" -p 2>/dev/null | grep -q '›'
}

cmd_ensure() {
  local repo="" model="${CODEX_MODEL:-}" effort="${CODEX_EFFORT:-high}"
  while [ $# -gt 0 ]; do case "$1" in
    --repo)   repo="$2"; shift 2 ;;
    --model)  model="$2"; shift 2 ;;
    --effort) effort="$2"; shift 2 ;;
    *) die "ensure: unknown arg $1" ;;
  esac; done
  repo="$(repo_root "${repo:-$PWD}")"

  local pane; pane="$(find_tagged "$repo")"
  if [ -n "$pane" ] && pane_alive "$pane"; then echo "$pane"; return 0; fi

  # Launch through the user's login shell so PATH managers (volta/nvm/asdf/
  # homebrew) are loaded; a bare `codex` via tmux's non-login shell can be
  # missing from PATH and the pane exits instantly.
  local sh="${SHELL:-/bin/sh}"
  local codex_cmd="codex -c model_reasoning_effort=${effort}"
  [ -n "$model" ] && codex_cmd="codex -m ${model} -c model_reasoning_effort=${effort}"

  # Two-step launch (bare shell first, then type the command) so an early exit
  # (e.g. the first-run trust prompt) never destroys the pane with it.
  if [ -n "${TMUX:-}" ]; then
    pane="$(tmux split-window -dh -t "$(tmux display-message -p '#{pane_id}')" \
      -c "$repo" -P -F '#{pane_id}' "$sh -l")" || die "split-window failed"
  else
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      pane="$(tmux new-window -t "$SESSION" -n "$(basename "$repo" | tr ' ' '-')" \
        -c "$repo" -P -F '#{pane_id}' "$sh -l")" || die "new-window failed"
    else
      tmux new-session -d -s "$SESSION" -n "$(basename "$repo" | tr ' ' '-')" \
        -c "$repo" -x 220 -y 50 "$sh -l" || die "new-session failed"
      pane="$(tmux list-panes -st "$SESSION" -F '#{pane_id}' | tail -1)"
    fi
  fi

  tmux set-option -pt "$pane" @cwc_role codex
  tmux set-option -pt "$pane" @cwc_repo "$repo"
  tmux set-option -pt "$pane" @cwc_launched_by "codex-pane.sh"

  sleep 2
  tmux send-keys -t "$pane" -l "$codex_cmd"
  sleep 1
  tmux send-keys -t "$pane" Enter

  # Wait for boot; auto-accept the first-run directory trust prompt (defaults to Yes).
  local i=0
  while [ $i -lt 24 ]; do
    sleep 5; i=$((i+1))
    if tmux capture-pane -t "$pane" -p 2>/dev/null | grep -qi 'Do you trust'; then
      tmux send-keys -t "$pane" Enter; sleep 3; continue
    fi
    idle_prompt "$pane" && { echo "$pane"; return 0; }
  done
  die "ensure: Codex TUI did not become ready in $((24*5))s (pane $pane kept for inspection)"
}

cmd_send() {
  local pane="${1:-}"; shift || die "send: pane id required"
  local msg="$*"
  [ -n "$pane" ] && [ -n "$msg" ] || die "send: usage: send <pane> <message>"
  pane_alive "$pane" || die "send: pane $pane not found"

  # Record a baseline so `wait` can require the screen to have moved past it.
  tmux set-option -pt "$pane" @cwc_baseline "$(hash_capture "$pane")"

  tmux send-keys -t "$pane" C-u          # clear any autocomplete ghost text
  tmux send-keys -t "$pane" -l "$msg"
  sleep 1
  tmux send-keys -t "$pane" Enter        # Enter separately: a busy TUI swallows same-instant Enter
  sleep 3

  # If the exact text still sits in the composer, the Enter was swallowed — resend once.
  if tmux capture-pane -t "$pane" -p | grep -qF "$(printf '%s' "$msg" | head -c 80)"; then
    if ! working "$pane"; then tmux send-keys -t "$pane" Enter; fi
  fi
}

cmd_wait() {
  local pane="${1:-}"; shift || die "wait: pane id required"
  local timeout=600
  while [ $# -gt 0 ]; do case "$1" in
    --timeout) timeout="$2"; shift 2 ;;
    *) die "wait: unknown arg $1" ;;
  esac; done
  pane_alive "$pane" || die "wait: pane $pane not found"

  local baseline elapsed=0 stable=0 prev="" cur
  baseline="$(tmux show-options -pt "$pane" -v @cwc_baseline 2>/dev/null || true)"

  while [ "$elapsed" -lt "$timeout" ]; do
    sleep "$POLL"; elapsed=$((elapsed+POLL))
    if needs_input "$pane"; then echo "NEEDS_INPUT"; return 2; fi
    if working "$pane"; then stable=0; prev=""; continue; fi
    cur="$(hash_capture "$pane")"
    # DONE requires: past the baseline, idle composer back, and a stable screen.
    if [ -n "$baseline" ] && [ "$cur" = "$baseline" ]; then continue; fi
    if ! idle_prompt "$pane"; then continue; fi
    if [ "$cur" = "$prev" ]; then stable=$((stable+1)); else stable=1; fi
    prev="$cur"
    if [ "$stable" -ge "$STABLE_POLLS" ]; then echo "DONE"; return 0; fi
  done
  echo "TIMEOUT"; return 3
}

cmd_capture() {
  local pane="${1:-}"; shift || die "capture: pane id required"
  local lines=300
  while [ $# -gt 0 ]; do case "$1" in
    --lines) lines="$2"; shift 2 ;;
    *) die "capture: unknown arg $1" ;;
  esac; done
  tmux capture-pane -t "$pane" -p -S "-$lines"
}

cmd_cleanup() {
  local pane="${1:-}"
  [ -n "$pane" ] || die "cleanup: pane id required"
  pane_alive "$pane" || return 0
  local by; by="$(tmux show-options -pt "$pane" -v @cwc_launched_by 2>/dev/null || true)"
  [ "$by" = "codex-pane.sh" ] || die "cleanup: refusing to kill pane $pane (not launched by this script)"
  tmux kill-pane -t "$pane"
}

case "${1:-}" in
  ensure)  shift; cmd_ensure  "$@" ;;
  send)    shift; cmd_send    "$@" ;;
  wait)    shift; cmd_wait    "$@" ;;
  capture) shift; cmd_capture "$@" ;;
  cleanup) shift; cmd_cleanup "$@" ;;
  *) sed -n '2,20p' "$0"; exit 1 ;;
esac
