#!/bin/sh
# rabbits Stop hook — 세션별 런 마커 기반 종료 가드.
# 이 세션의 마커(.rabbits/runs/<session_id>.md)가 있으면 런 진행 중으로 보고 종료를 막는다.
# 다른 세션의 마커는 보지 않는다. 같은 리포에서 세션 여럿이 돌아도 서로의 턴 종료를 막지 않는다.
# 기다릴 백그라운드 워커나 워크플로가 있으면 막지 않는다. 끝나면 완료 알림이 이 세션을 다시 깨운다.
# 순수 sh. stdin JSON 은 공백 없는 한 줄로 온다(2.1.280 실측). 문자열 값 안의 따옴표는 이스케이프되므로
# `"type":"subagent"` 부분 문자열은 background_tasks 항목에서만 나온다.
# 하니스가 연속 8회 block 뒤 훅을 무시하므로 stop_hook_active 조기 통과는 두지 않는다(지속 강제가 목적).

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
input=$(cat)
flat=$(printf '%s' "$input" | tr -d ' \t\r\n')
sid=$(printf '%s' "$flat" | sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p' | head -n 1)
# 세션 ID 를 못 읽으면 어느 마커가 이 세션 것인지 알 수 없다. 막지 않는다.
[ -n "$sid" ] || exit 0

runs="$project_dir/.rabbits/runs"
marker="$runs/$sid.md"
blocklog="$runs/$sid.blocks"

if [ ! -f "$marker" ]; then
  # 런이 끝났다. 이 세션의 지난 차단 로그를 지워 로그를 한 런 범위로 한정한다.
  { [ -f "$blocklog" ] && rm -f "$blocklog"; } 2>/dev/null || true
  exit 0
fi

case "$flat" in
  *'"type":"subagent"'*|*'"type":"workflow"'*) exit 0 ;;
esac

# 워커가 막 끝나 완료 알림이 대기열에 들어갔는데 아직 전달 전인 순간이 있다. 이때 background_tasks 는
# 비어 있지만 하니스가 곧 그 알림으로 새 턴을 연다(0.37.0 스모크: 알림 enqueue 1초 뒤 Stop, 오차단 1회).
# 세션 기록 끝부분의 마지막 queue-operation 이 enqueue 면 전달 대기 중으로 보고 막지 않는다.
# ponytail: 마지막 연산만 본다. 기록 전체의 enqueue·dequeue·remove 누계는 유실 항목 때문에 맞지 않는다
# (로컬 기록 79개 중 10개가 잔량 양수였고 그 대부분은 마지막 연산이 dequeue 였다).
# 경로는 공백을 지우지 않은 원문에서 뽑는다. 사용자 폴더 이름에 공백이 있을 수 있다.
tp=$(printf '%s' "$input" | sed -n 's/.*"transcript_path":"\([^"]*\)".*/\1/p' | head -n 1 | sed 's/\\\\/\//g')
if [ -n "$tp" ] && [ -f "$tp" ]; then
  last=$(tail -c 1000000 "$tp" | grep -o '^{"type":"queue-operation","operation":"[a-z]*"' | tail -n 1)
  case "$last" in *'"enqueue"') exit 0 ;; esac
fi

# 차단 이력. 기다릴 워커도 없는데 턴을 끝내려 했다는 기록이다. self-audit 검사 2 가 읽는다.
# 훅은 하니스가 호출하므로 대장 자기 신고보다 믿을 만한 출처다. 로그 실패는 삼킨다.
{ date +%s >> "$blocklog"; } 2>/dev/null || true

printf '%s\n' '{"decision":"block","reason":"rabbits 런 진행 중인데 기다릴 워커가 없다. 작업을 이어가라. 사용자 답이 필요하면 AskUserQuestion 으로 물어라. 런이 끝났으면 단계 6 을 마치고 이 세션의 마커(.rabbits/runs/<세션>.md)를 지워라."}'
exit 0
