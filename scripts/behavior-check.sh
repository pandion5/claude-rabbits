#!/bin/sh
# rabbits 행위 검증 — 규약이 문서에 적혀 있는지(정적 grep)가 아니라 실제로 그렇게
# 동작하는지를 임시 디렉토리에서 시뮬레이션한다. QA 원장의 문자열 존재 검사를 보완한다.
# 사용법: sh scripts/behavior-check.sh   (인자 없음, 어느 디렉토리에서 호출해도 무방)
# 3사이클 각각 PASS/FAIL을 출력하고 하나라도 FAIL이면 비제로 종료.
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

# ── 사이클 1: 마커 상태 전이 (run-active → run-waiting → 삭제) ──────────────
# 계약: active면 decision=block·exit 0 / waiting이면 무출력·exit 0(대기 규약) / 없으면 무출력·exit 0.
c1=''
proj="$TMP/proj"
mkdir -p "$proj/.rabbits"
guard="$REPO/hooks/stop-guard.sh"

printf '런 진행 중\n' > "$proj/.rabbits/run-active.md"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
[ "$rc" = 0 ] || c1="$c1
active: exit=$rc (기대 0)"
printf '%s' "$out" | grep -q '"decision"[ ]*:[ ]*"block"' || c1="$c1
active: decision=block 미검출 (출력: $out)"
printf '%s' "$out" | grep -q '"reason"[ ]*:[ ]*"[^"]\{1,\}"' || c1="$c1
active: reason이 비었다 (출력: $out)"

mv "$proj/.rabbits/run-active.md" "$proj/.rabbits/run-waiting.md"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || c1="$c1
waiting: 무출력·exit 0 계약 위반 (exit=$rc, 출력='$out')"

rm -f "$proj/.rabbits/run-waiting.md"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$guard")
rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || c1="$c1
마커 없음: 무출력·exit 0 계약 위반 (exit=$rc, 출력='$out')"

report "1. 마커 사이클 — active=block / waiting=통과 / 삭제=통과" "$c1"

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
(cd "$REPO" && sh scripts/release.sh --dry-run "$ver" "behavior-check marker" README.md .rabbits/run-active.md) \
  > "$TMP/rel-block.log" 2>&1
rc=$?
[ "$rc" != 0 ] || c3="$c3
마커를 대상에 넣었는데 EXIT=0 — 차단되지 않았다"
grep -q '런 마커가 대상 목록에 있다' "$TMP/rel-block.log" || c3="$c3
마커 차단 사유 메시지가 없다: $(tail -n 2 "$TMP/rel-block.log")"

report "3. 릴리스 가드 — 안전 드라이런 EXIT=0 / 마커 포함 시 차단" "$c3"

if [ "$FAILED" = 0 ]; then
  echo "== 행위 검증 3사이클 전부 PASS =="
else
  echo "== 행위 검증 FAIL — 위 사유를 확인하라 ==" >&2
fi
exit "$FAILED"
