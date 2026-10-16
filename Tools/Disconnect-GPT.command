#!/bin/zsh
set -euo pipefail
DOTS_PACKAGE_DIR="${0:A:h}"
DOTS_APP_PATH="${1:-/Applications/Dots.app}"
DOTS_HOOKS_PATH="${CODEX_HOME:-$HOME/.codex}/hooks.json"
print "설정: $DOTS_HOOKS_PATH"
print 'Dots 핸들러만 제거합니다. 다른 훅은 보존하고 백업합니다.'
read 'DOTS_CONFIRM?계속하려면 YES 입력: '
[[ "$DOTS_CONFIRM" == YES ]] || exit 0
"$DOTS_PACKAGE_DIR/DotsHookConfig" remove "$DOTS_HOOKS_PATH" "$DOTS_APP_PATH"
read '?Enter를 누르면 종료합니다.'
