#!/usr/bin/env bash
# Easter-egg agent hook: roughly once in a thousand prompts, show a random
# useless fact. The odds are drawn fresh each run with coreutils' shuf, so the
# script keeps no state and stays valid as a read-only Nix store symlink.
#
# The fact is untrusted third-party text, so it is treated as data and never as
# code: it is sanitised to one short printable-ASCII line, handed to jq as a
# value (`--arg`, never as a program or a format string), and emitted as the
# `systemMessage` field, which Claude Code shows to the user rather than adding
# to the model's context. Nothing in the response is ever evaluated, sourced or
# executed, and if jq is missing the hook stays silent instead of assembling
# JSON by hand.
set -euo pipefail

# 0.1% chance per invocation. Cheapest possible miss: one builtin test and one
# shuf, with no network access and no output.
[ "$(shuf -i 1-1000 -n 1)" -eq 1 ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

# `--proto '=https'` keeps a redirect from downgrading to plaintext. The
# timeout is deliberately tight: this is one small GET, and a slow answer is
# worth dropping rather than making the user wait on an easter egg.
api_response=$(curl -fsSL --proto '=https' -m 1 \
  -H "Accept: application/json" \
  https://uselessfacts.jsph.pl/api/v2/facts/random || true)
[ -n "$api_response" ] || exit 0

# Pull the string value out with a literal jq program; the response is input,
# not code. Then drop control characters and non-ASCII (which covers ANSI
# escapes and JSON/terminal metacharacters a hostile response might carry),
# squeeze whitespace and cap the length before anything is shown.
fact=$(printf '%s' "$api_response" | jq -r '.text // empty' 2>/dev/null || true)
fact=$(printf '%s' "$fact" | tr -d '\000-\037\177-\377' | tr -s ' ' | cut -c1-200)
[ -n "$fact" ] || exit 0

jq -n --arg message "🎉 Did you know that: ${fact}" \
  '{ systemMessage: $message }'
