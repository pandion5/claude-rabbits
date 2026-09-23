#!/bin/sh
# rabbits SessionStart hook(compact|resume) — 런 복구 문맥.
# 자동 압축 뒤 스킬 본문은 앞 5,000토큰만 다시 붙는다. 사용자 중단이나 API 오류로 Stop 없이 끊긴
# 런은 재개 때까지 드러나지 않는다. 이 세션에 런 마커가 있으면 마커·보고서·스킬 경로를 문맥으로 넣는다.
# 마커가 없으면 아무것도 내지 않는다.
# 문구는 사실 서술로 쓴다. 명령형 시스템 지시처럼 보이면 프롬프트 주입 방어에 걸릴 수 있다(공식 문서
# hooks "Add context for Claude"). 무엇을 할지는 SKILL.md 앞부분(압축 뒤에도 남는 곳)에 있다.
# 한계: 2.1.280 대화형 --resume 에서는 훅이 돌고 출력도 냈는데 모델 문맥에 붙지 않았다(2회 중 2회).
# -p 재개와 /compact 에서는 붙었다. 대화형 재개 뒤에는 종료 가드가 첫 턴 종료를 막아 런을 드러낸다.

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
input=$(cat)
flat=$(printf '%s' "$input" | tr -d ' \t\r\n')
sid=$(printf '%s' "$flat" | sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$sid" ] || exit 0
marker="$project_dir/.rabbits/runs/$sid.md"
[ -f "$marker" ] || exit 0

skill="${CLAUDE_PLUGIN_ROOT:-<rabbits 플러그인 루트>}/skills/run/SKILL.md"
report=$(sed -n 's/^- *보고서: *//p' "$marker" 2>/dev/null | head -n 1)
msg="이 세션에서 rabbits 런이 진행 중이다. 런 마커는 $marker 이고 보고서 경로는 ${report:-마커에 적혀 있지 않다}. 압축이나 재개 뒤에는 스킬 본문 뒤쪽이 빠져 있을 수 있으며 스킬 원문은 $skill 이다. 파견한 뒤 결과를 받지 못한 워커가 있을 수 있다."

# JSON 문자열로 넣는다. 윈도 경로의 역슬래시와 따옴표를 이스케이프한다.
esc=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
exit 0
