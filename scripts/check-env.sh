#!/usr/bin/env bash
# check-env.sh — verify the environment claude-with-codex depends on.
# Safe to run anywhere; makes no changes, only reports.

set -u

ok=0; warn=0; fail=0
pass()  { printf '  ✅ %s\n' "$1"; ok=$((ok+1)); }
note()  { printf '  ⚠️  %s\n' "$1"; warn=$((warn+1)); }
miss()  { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

echo "claude-with-codex environment check"
echo

echo "[1/4] tmux"
if command -v tmux >/dev/null 2>&1; then
  pass "tmux found: $(tmux -V)"
else
  miss "tmux not found — the entire collaboration channel runs through tmux."
  echo "     install: macOS  → brew install tmux"
  echo "              Debian → sudo apt install tmux"
fi

echo "[2/4] Codex CLI"
if command -v codex >/dev/null 2>&1; then
  pass "codex found: $(codex --version 2>/dev/null | head -1)"
else
  miss "codex not found — install the OpenAI Codex CLI."
  echo "     install: npm install -g @openai/codex   (or: brew install codex)"
  echo "     then:    codex login"
fi

echo "[3/4] Codex config"
if [ -f "$HOME/.codex/config.toml" ]; then
  pass "~/.codex/config.toml present (launch flags inherit from it)"
else
  note "~/.codex/config.toml not found — codex will use built-in defaults."
  echo "     Run codex once interactively to complete login/setup."
fi

echo "[4/4] login-shell PATH (tmux launches panes through a non-login shell)"
LOGIN_SHELL="${SHELL:-/bin/sh}"
if "$LOGIN_SHELL" -lc 'command -v codex' >/dev/null 2>&1; then
  pass "codex resolvable from a login shell ($LOGIN_SHELL -lc)"
else
  if command -v codex >/dev/null 2>&1; then
    note "codex is on PATH here but NOT in a login shell — panes launched as"
    echo "     '$LOGIN_SHELL -lc \"codex …\"' would exit instantly."
    echo "     Fix: make your version manager (volta/nvm/asdf) or npm global bin"
    echo "     available in your login-shell init file (~/.zprofile, ~/.profile …)."
  else
    note "skipped (codex not installed)"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "Result: $fail missing, $warn warnings — fix the ❌ items before using the skills."
  exit 1
elif [ "$warn" -gt 0 ]; then
  echo "Result: ready with $warn warnings."
else
  echo "Result: all good — you're ready."
fi
