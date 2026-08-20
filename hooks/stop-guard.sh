#!/bin/sh
# rabbits Stop hook — 마커 기반 종료 가드.
# .rabbits/run-active.md 가 있으면 런 진행 중으로 보고 종료를 차단해 계속 진행시킨다.
# 순수 sh(외부 의존 없음 — date/tail 등 표준 유틸만) — stdin JSON 파싱 불요.
# 하니스 8회 block 캡이 무한루프를 막으므로 stop_hook_active 조기통과 분기는 두지 않는다(지속 강제가 목적).

# 프로젝트 디렉토리: env 우선, 비어 있으면 현재 작업 디렉토리로 폴백.
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
marker="$project_dir/.rabbits/run-active.md"
waiting="$project_dir/.rabbits/run-waiting.md"
blocklog="$project_dir/.rabbits/run-blocks.log"

# 마커 없음 = 비런 세션 → 아무 출력 없이 통과(오버헤드 0).
if [ ! -f "$marker" ]; then
  # 대기 마커도 없으면 런이 끝난 것 → 지난 런의 차단 로그를 비운다(로그를 이번 런 범위로 한정).
  # 대기 중(run-waiting.md)에는 지우지 않는다 — 같은 런의 앞선 차단 증거가 사라지면 안 된다.
  if [ ! -f "$waiting" ] && [ -s "$blocklog" ]; then
    { true > "$blocklog"; } 2>/dev/null || true
  fi
  exit 0
fi

# 차단 이력 기록 — 차단됐다 = 대장이 대기 전환 없이 턴을 끝냈다는 뜻이고, 마커 레저에는 안 남는다.
# self-audit 검사 2가 이 로그로 "미신고 대기"를 잡는다(훅은 하니스가 호출하므로 대장이 못 만지는 출처).
# 마지막 50줄만 유지해 무한 증식을 막고, 로그 실패는 전부 삼킨다 — 가드 동작이 언제나 우선이다.
{ date +%s >> "$blocklog" && tail -n 50 "$blocklog" > "$blocklog.tmp" && mv "$blocklog.tmp" "$blocklog"; } 2>/dev/null || true

# 마커 있음 = 런 진행 중 → 종료 차단(decision:block) 후 계속 진행 지시.
printf '%s\n' '{"decision":"block","reason":"rabbits 런 진행 중(.rabbits/run-active.md 존재) — 단계 6 최종 리포트를 완료하고 마커 파일을 삭제한 뒤 종료하라. 런이 이미 끝났다면 마커만 삭제하면 된다."}'
exit 0
