#!/bin/sh
# rabbits 행위 검증 — 규약이 문서에 적혀 있는지(정적 grep)가 아니라 실제로 그렇게
# 동작하는지를 임시 디렉토리에서 시뮬레이션한다. QA 원장의 문자열 존재 검사를 보완한다.
# 사용법: sh scripts/behavior-check.sh   (인자 없음, 어느 디렉토리에서 호출해도 무방)
# 4사이클 각각 PASS/FAIL을 출력하고 하나라도 FAIL이면 비제로 종료.
# 훅 입력은 2.1.280 실측 형식(공백 없는 한 줄 JSON)을 따른다.
# 임시물은 mktemp -d 하위에만 만들고 trap으로 자기 정리 — 리포를 오염시키지 않는다.
set -u

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

FAILED=0

# 사이클 판정 출력 — $1=사이클 이름, $2=실패 사유(빈 문자열이면 PASS).
report() {
  if [ -z "$2" ]; then
    echo "[PASS] $1"
  else
    echo "[FAIL] $1"
    printf '%s\n' "$2" | sed '/^$/d; s/^/       · /'
    FAILED=1
  fi
}

# ── 사이클 1: 세션별 마커와 종료 가드 ───────────────────────────────────────
# 계약: 이 세션 마커가 있고 기다릴 워커가 없으면 decision=block·reason·exit 0·차단 로그 1줄 /
# 백그라운드 워커가 있거나 완료 알림이 대기열에 있으면 무출력 / 다른 세션이면 무출력 / 마커를 지우면 무출력이고 차단 로그도 지워진다.
c1=''
proj="$TMP/proj"
mkdir -p "$proj/.rabbits/runs"
guard="$REPO/hooks/stop-guard.sh"
stop_in() {  # $1=세션 ID, $2=background_tasks 배열 JSON, $3=세션 기록 경로(선택)
  printf '{"session_id":"%s","transcript_path":"%s","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"끝","background_tasks":%s,"session_crons":[]}' "$1" "${3:-}" "$2"
}
worker='[{"id":"a1","type":"subagent","status":"running","description":"x","agent_type":"general-purpose"}]'

printf -- '- 작업: 런 진행 중\n' > "$proj/.rabbits/runs/S1.md"
out=$(stop_in S1 '[]' | CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
[ "$rc" = 0 ] || c1="$c1
대기 없음: exit=$rc (기대 0)"
printf '%s' "$out" | grep -q '"decision"[ ]*:[ ]*"block"' || c1="$c1
대기 없음: decision=block 미검출 (출력: $out)"
printf '%s' "$out" | grep -q '"reason"[ ]*:[ ]*"[^"]\{1,\}"' || c1="$c1
대기 없음: reason이 비었다 (출력: $out)"
n=$(grep -c '^[0-9]' "$proj/.rabbits/runs/S1.blocks" 2>/dev/null || echo 0)
[ "$n" = 1 ] || c1="$c1
대기 없음: 차단 로그 ${n}줄 (기대 1)"

out=$(stop_in S1 "$worker" | CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || c1="$c1
워커 대기 중: 무출력·exit 0 계약 위반 (exit=$rc, 출력='$out')"

out=$(stop_in S2 '[]' | CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || c1="$c1
다른 세션: 무출력·exit 0 계약 위반 (exit=$rc, 출력='$out')"

# 완료 알림이 대기열에 있으면(마지막 queue-operation 이 enqueue) 통과, 전달됐으면(dequeue) 차단.
# 경로에 공백이 있어도 읽어야 한다.
tdir="$TMP/user dir"
mkdir -p "$tdir"
tr_path="$tdir/S1.jsonl"
printf '%s\n' '{"type":"queue-operation","operation":"enqueue","content":"<task-notification>"}' > "$tr_path"
# 윈도에서는 하니스가 주는 모양(C:\\Users\\...)으로 넣어 역슬래시 변환까지 확인한다.
tr_json="$tr_path"
command -v cygpath > /dev/null 2>&1 && tr_json=$(cygpath -w "$tr_path" | sed 's/\\/\\\\/g')
out=$(stop_in S1 '[]' "$tr_json" | CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || c1="$c1
알림 대기열: 무출력·exit 0 계약 위반 (exit=$rc, 출력='$out')"
printf '%s\n' '{"type":"queue-operation","operation":"dequeue"}' >> "$tr_path"
out=$(stop_in S1 '[]' "$tr_json" | CLAUDE_PROJECT_DIR="$proj" sh "$guard")
printf '%s' "$out" | grep -q '"decision"[ ]*:[ ]*"block"' || c1="$c1
알림 전달 뒤: decision=block 미검출 (출력: $out)"

rm -f "$proj/.rabbits/runs/S1.md"
out=$(stop_in S1 '[]' | CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || c1="$c1
마커 없음: 무출력·exit 0 계약 위반 (exit=$rc, 출력='$out')"
[ ! -e "$proj/.rabbits/runs/S1.blocks" ] || c1="$c1
마커 없음: 지난 런 차단 로그가 지워지지 않았다"

report "1. 세션별 마커 가드 — 대기 없음=block / 워커 대기=통과 / 알림 대기열=통과 / 다른 세션=통과 / 삭제=통과" "$c1"

# ── 사이클 2: 백로그 소비 시뮬레이션 ────────────────────────────────────────
# 계약: 최상단 미완료 1건만 - [x]로 바뀌고, 나머지 행은 바이트 그대로 남는다.
c2=''
bl="$TMP/backlog.md"
cat > "$bl" <<'EOF'
# 백로그

- [ ] 항목A — 첫째 줄
- [ ] 항목B — 둘째 줄
- [ ] 항목C — 셋째 줄
EOF

# 소비 처리 — $1이 있으면 "(미해결: 사유)" 표기를 덧붙인다.
consume() {
  awk -v reason="${1-}" '
    !hit && /^- \[ \] / {
      sub(/^- \[ \] /, "- [x] ")
      if (reason != "") $0 = $0 " (미해결: " reason ")"
      hit = 1
    }
    { print }
  '
}

# 다른 항목 불변 대조 — 소비 대상 행만 걷어낸 나머지를 원문과 diff.
untouched() {
  # $1=대상 표식, $2=소비 전 파일, $3=소비 후 파일
  grep -v -- "$1" "$2" > "$TMP/rest-before"
  grep -v -- "$1" "$3" > "$TMP/rest-after"
  diff "$TMP/rest-before" "$TMP/rest-after" > /dev/null 2>&1
}

consume < "$bl" > "$TMP/after1"
n=$(grep -c '^- \[ \] ' "$TMP/after1")
[ "$n" = 2 ] || c2="$c2
소비 1회 후 남은 미완료가 ${n}건 (기대 2)"
grep -q '^- \[x\] 항목A — 첫째 줄$' "$TMP/after1" || c2="$c2
최상단 항목이 '- [x] 항목A — 첫째 줄'로 바뀌지 않았다"
untouched '항목A' "$bl" "$TMP/after1" || c2="$c2
소비 대상이 아닌 행이 변형됐다(원문 대조 실패)"

# 미해결 표기 케이스 — 다음 미완료(항목B)를 사유와 함께 소비.
consume '재현 실패' < "$TMP/after1" > "$TMP/after2"
grep -q '^- \[x\] 항목B — 둘째 줄 (미해결: 재현 실패)$' "$TMP/after2" || c2="$c2
미해결 표기 형식이 '- [x] 항목 (미해결: 사유)'와 다르다"
n=$(grep -c '^- \[ \] ' "$TMP/after2")
[ "$n" = 1 ] || c2="$c2
미해결 소비 후 남은 미완료가 ${n}건 (기대 1)"
untouched '항목B' "$TMP/after1" "$TMP/after2" || c2="$c2
미해결 소비에서 대상 외 행이 변형됐다(원문 대조 실패)"

report "2. 백로그 소비 — 최상단 1건만 체크 / 미해결 표기 / 타 항목 불변" "$c2"

# ── 사이클 3: 릴리스 가드 (드라이런만, 커밋·push 없음) ──────────────────────
c3=''
ver=$(sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$REPO/.claude-plugin/plugin.json")
[ -n "$ver" ] || c3="$c3
plugin.json에서 version을 읽지 못했다"

# 안전 인자(현재 버전 = 상향 없음, 대상은 README.md 하나) → 통과해야 한다.
(cd "$REPO" && sh scripts/release.sh --dry-run "$ver" "behavior-check dry-run" README.md) \
  > "$TMP/rel-ok.log" 2>&1
rc=$?
[ "$rc" = 0 ] || c3="$c3
안전 인자 드라이런 EXIT=$rc (기대 0): $(tail -n 2 "$TMP/rel-ok.log")"

# 런 마커를 대상에 섞으면 반드시 차단돼야 한다.
(cd "$REPO" && sh scripts/release.sh --dry-run "$ver" "behavior-check marker" README.md .rabbits/runs/S1.md) \
  > "$TMP/rel-block.log" 2>&1
rc=$?
[ "$rc" != 0 ] || c3="$c3
마커를 대상에 넣었는데 EXIT=0 — 차단되지 않았다"
grep -q '런 마커가 대상 목록에 있다' "$TMP/rel-block.log" || c3="$c3
마커 차단 사유 메시지가 없다: $(tail -n 2 "$TMP/rel-block.log")"

report "3. 릴리스 가드 — 안전 드라이런 EXIT=0 / 마커 포함 시 차단" "$c3"

# ── 사이클 4: 결과 블록 게이트와 복구 훅 ────────────────────────────────────
# 계약: 이 세션 런이고 위임문에 계약이 있는데 최종 메시지에 블록이 없으면 block(한 번) /
# 블록이 있거나 두 번째 멈춤이거나 계약 없는 에이전트면 무출력 / 복구 훅은 이 세션 마커가 있을 때만 문맥을 낸다.
c4=''
gate="$REPO/hooks/result-gate.sh"
recover="$REPO/hooks/recover.sh"
printf -- '- 작업: 런 진행 중\n- 보고서: reports/x.md\n' > "$proj/.rabbits/runs/S1.md"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"작업. 결과는 rabbits-result 블록으로"}}' > "$TMP/worker.jsonl"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Reply OK"}}' > "$TMP/other.jsonl"
sub_in() {  # $1=stop_hook_active, $2=기록 경로, $3=최종 메시지(JSON 이스케이프된 문자열)
  printf '{"session_id":"S1","hook_event_name":"SubagentStop","stop_hook_active":%s,"agent_id":"a1","agent_type":"general-purpose","agent_transcript_path":"%s","last_assistant_message":"%s","background_tasks":[],"session_crons":[]}' "$1" "$2" "$3"
}
blk='완료\n```rabbits-result\noutcome: DONE\nself_check:\n  - C1: ✓\n```'

out=$(sub_in false "$TMP/worker.jsonl" '끝났다' | CLAUDE_PROJECT_DIR="$proj" sh "$gate")
printf '%s' "$out" | grep -q '"decision"[ ]*:[ ]*"block"' || c4="$c4
블록 없는 워커: block 미검출 (출력: $out)"
out=$(sub_in false "$TMP/worker.jsonl" "$blk" | CLAUDE_PROJECT_DIR="$proj" sh "$gate")
[ -z "$out" ] || c4="$c4
블록 있는 워커: 무출력이어야 한다 (출력: $out)"
out=$(sub_in true "$TMP/worker.jsonl" '끝났다' | CLAUDE_PROJECT_DIR="$proj" sh "$gate")
[ -z "$out" ] || c4="$c4
두 번째 멈춤: 무출력이어야 한다 (출력: $out)"
out=$(sub_in false "$TMP/other.jsonl" '끝났다' | CLAUDE_PROJECT_DIR="$proj" sh "$gate")
[ -z "$out" ] || c4="$c4
계약 없는 에이전트: 무출력이어야 한다 (출력: $out)"

out=$(printf '{"session_id":"S1","hook_event_name":"SessionStart","source":"compact"}' | CLAUDE_PROJECT_DIR="$proj" CLAUDE_PLUGIN_ROOT="$REPO" sh "$recover")
printf '%s' "$out" | grep -q '"additionalContext"[ ]*:[ ]*".*SKILL.md' || c4="$c4
복구 훅: 이 세션 마커가 있는데 SKILL.md 경로가 든 문맥이 없다 (출력: $out)"
out=$(printf '{"session_id":"S2","hook_event_name":"SessionStart","source":"resume"}' | CLAUDE_PROJECT_DIR="$proj" sh "$recover")
[ -z "$out" ] || c4="$c4
복구 훅: 다른 세션인데 문맥을 냈다 (출력: $out)"

rm -f "$proj/.rabbits/runs/S1.md"
out=$(sub_in false "$TMP/worker.jsonl" '끝났다' | CLAUDE_PROJECT_DIR="$proj" sh "$gate")
[ -z "$out" ] || c4="$c4
런 없음: 게이트가 무출력이어야 한다 (출력: $out)"

report "4. 결과 블록 게이트·복구 훅 — 누락=재요구 / 블록·두 번째·무계약=통과 / 복구 문맥은 이 세션만" "$c4"

if [ "$FAILED" = 0 ]; then
  echo "== 행위 검증 4사이클 전부 PASS =="
else
  echo "== 행위 검증 FAIL — 위 사유를 확인하라 ==" >&2
fi
exit "$FAILED"
