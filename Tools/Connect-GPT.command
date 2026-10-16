#!/bin/zsh
set -euo pipefail
DOTS_APP_PATH="${1:-/Applications/Dots.app}"
DOTS_HOOKS_PATH="${CODEX_HOME:-$HOME/.codex}/hooks.json"
if [[ ! -x "$DOTS_APP_PATH/Contents/MacOS/Dots" ]]; then
  print 'Dots.app을 응용 프로그램 폴더에 먼저 복사해 주세요.'
  print '다른 위치라면 터미널에서 이 스크립트 뒤에 앱의 절대 경로를 넣어 실행하세요.'
  read '?Enter를 누르면 종료합니다.'
  exit 1
fi
if [[ ! -x "$DOTS_APP_PATH/Contents/MacOS/DotsHookConfig" ]]; then
  print '이 Dots.app에는 연결 도구가 없습니다. 최신 소스에서 zsh build.sh로 다시 빌드해 주세요.'
  read '?Enter를 누르면 종료합니다.'
  exit 1
fi
print "앱: $DOTS_APP_PATH"
print "수정할 설정: $DOTS_HOOKS_PATH"
print '기존 훅을 보존하고 백업한 뒤 Dots 핸들러 4개를 등록합니다.'
print 'Codex 훅 신뢰/운영체제 권한은 변경하지 않습니다.'
read 'DOTS_CONFIRM?계속하려면 YES 입력: '
[[ "$DOTS_CONFIRM" == YES ]] || exit 0
"$DOTS_APP_PATH/Contents/MacOS/DotsHookConfig" install "$DOTS_HOOKS_PATH" "$DOTS_APP_PATH"
print '완료. Codex /hooks에서 Dots 핸들러를 검토하고 신뢰한 뒤 새 질문으로 확인하세요.'
read '?Enter를 누르면 종료합니다.'
