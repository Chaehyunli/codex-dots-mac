#!/bin/zsh
set -euo pipefail
DOTS_APP_PATH="${1:-/Applications/Dots.app}"
DOTS_HOOKS_PATH="${CODEX_HOME:-$HOME/.codex}/hooks.json"
if [[ ! -x "$DOTS_APP_PATH/Contents/MacOS/DotsHookConfig" ]]; then
  print '이 Dots.app에는 연결 도구가 없습니다. GPT-CONNECTION.md의 수동 제거 방법을 사용하세요.'
  read '?Enter를 누르면 종료합니다.'
  exit 1
fi
print "설정: $DOTS_HOOKS_PATH"
print 'Dots 핸들러만 제거합니다. 다른 훅은 보존하고 백업합니다.'
read 'DOTS_CONFIRM?계속하려면 YES 입력: '
[[ "$DOTS_CONFIRM" == YES ]] || exit 0
"$DOTS_APP_PATH/Contents/MacOS/DotsHookConfig" remove "$DOTS_HOOKS_PATH" "$DOTS_APP_PATH"
read '?Enter를 누르면 종료합니다.'
