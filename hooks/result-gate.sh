#!/bin/sh
# rabbits SubagentStop hook — 결과 블록 게이트.
# 이 세션에 런 마커가 있고, 워커 위임문에 rabbits-result 계약이 있는데, 최종 메시지에 블록이 없으면
# 워커를 한 번 되돌려 블록을 붙이게 한다. decision block 의 reason 이 워커의 다음 지시가 되고,
# 대장이 받는 Agent 결과도 그 수정본이다(2.1.280 실측).
# 두 번째 멈춤(stop_hook_active true)은 통과시킨다. 그래도 블록이 없으면 단계 4 가 REVISE 로 처리한다.
# 경로를 못 읽는 등 판단할 수 없으면 통과한다. 게이트는 형식 보조이고 판정 주체가 아니다.

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
input=$(cat)
flat=$(printf '%s' "$input" | tr -d '\r\n')

case "$flat" in *'"stop_hook_active":true'*) exit 0 ;; esac
# 하니스 내부 에이전트(프롬프트 제안, /btw 등)는 agent_type 이 빈 문자열이다.
case "$flat" in *'"agent_type":""'*) exit 0 ;; esac

sid=$(printf '%s' "$flat" | sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$sid" ] && [ -f "$project_dir/.rabbits/runs/$sid.md" ] || exit 0

# 윈도 경로는 JSON 에서 `\\` 로 온다. 슬래시로 바꿔 쓴다.
tp=$(printf '%s' "$input" | sed -n 's/.*"agent_transcript_path":"\([^"]*\)".*/\1/p' | head -n 1 | sed 's/\\\\/\//g')
[ -n "$tp" ] && [ -f "$tp" ] || exit 0

# 워커 기록 첫 줄이 위임문이다. 결과 블록 계약이 없으면 rabbits 워커가 아니다.
head -n 1 "$tp" | grep -q 'rabbits-result' || exit 0

# 최종 메시지만 떼어 본다. 필드 순서가 달라 못 떼면 원문 전체를 본다.
msg=${flat#*'"last_assistant_message":"'}
msg=${msg%%'","background_tasks":'*}
case "$msg" in
  *'```rabbits-result'*'outcome:'*'self_check:'*) exit 0 ;;
esac

# auto 모드의 SubagentHandback 은 보고서를 툴 호출로 넘기므로 최종 메시지가 보고서가 아니다.
# 실제 툴 호출 기록(이스케이프되지 않은 키)이 있을 때만 판단하지 않고 통과한다.
tail -c 200000 "$tp" | grep -q '"name": *"SubagentHandback"' && exit 0

printf '%s\n' '{"decision":"block","reason":"rabbits-result 블록이 최종 메시지에 없다. 작업을 다시 하지 말고, 지금까지의 결과를 공통 규칙의 rabbits-result 블록(outcome, deliverable, evidence, commands_run, self_check, notes)으로 최종 메시지 끝에 붙여 다시 답하라."}'
exit 0
