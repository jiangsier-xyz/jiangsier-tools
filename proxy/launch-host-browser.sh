#!/usr/bin/env bash

nohup "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.openclaw/workspace/chrome-profile" \
  --profile-directory="Default" \
  --no-first-run \
  --no-default-browser-check \
  --remote-allow-origins="*" \
  &>/dev/null &
