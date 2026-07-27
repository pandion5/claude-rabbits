#!/bin/sh
# rabbits Stop hook — 마커 기반 종료 가드.
# .rabbits/run-active.md 가 있으면 런 진행 중으로 보고 종료를 차단해 계속 진행시킨다.
# 순수 sh(외부 의존 없음) — stdin JSON 파싱 불요. 하니스 8회 block 캡이 무한루프를 막으므로
# stop_hook_active 조기통과 분기는 두지 않는다(지속 강제가 목적).

# 프로젝트 디렉토리: env 우선, 비어 있으면 현재 작업 디렉토리로 폴백.
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
marker="$project_dir/.rabbits/run-active.md"

# 마커 없음 = 비런 세션 → 아무 출력 없이 통과(오버헤드 0).
if [ ! -f "$marker" ]; then
  exit 0
fi

# 마커 있음 = 런 진행 중 → 종료 차단(decision:block) 후 계속 진행 지시.
printf '%s\n' '{"decision":"block","reason":"rabbits 런 진행 중(.rabbits/run-active.md 존재) — 단계 6 최종 리포트를 완료하고 마커 파일을 삭제한 뒤 종료하라. 런이 이미 끝났다면 마커만 삭제하면 된다."}'
exit 0
