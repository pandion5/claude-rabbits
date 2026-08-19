#!/bin/sh
# rabbits 자기 감사 — 런 종료 직후 대장이 돌려 자기 규약 위반을 기계적으로 잡는다.
# 사용법: sh scripts/self-audit.sh [--in-run]   (어느 디렉토리에서 호출해도 무방)
#   --in-run: 런 진행 중 실행. 마커 잔존 검사(1번)만 건너뛴다.
# 파괴적 동작 없음(조회만 — rm·reset·force·add 미사용). 파일·git 상태로만 판정되는 것만 검사하고,
# 사람 판단이 필요한 것(면제 사유의 타당성, 수치 반올림 여부)은 검사하지 않는다.
# 6검사 각각 PASS/FAIL/SKIP을 출력하고 하나라도 FAIL이면 비제로 종료.
set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FAILED=0

# 판정 출력 — $1=검사 이름, $2=실패 사유(빈 문자열이면 PASS).
report() {
  if [ -z "$2" ]; then
    echo "[PASS] $1"
  else
    echo "[FAIL] $1"
    printf '%s\n' "$2" | sed '/^$/d; s/^/       · /'
    FAILED=1
  fi
}

# 건너뛴 검사 — 판정 불가 조건임을 남기되 FAILED에는 영향을 주지 않는다.
skip() {
  echo "[SKIP] $1"
  printf '%s\n' "$2" | sed '/^$/d; s/^/       · /'
}

IN_RUN=0
[ "${1-}" = "--in-run" ] && IN_RUN=1

ACTIVE="$REPO/.rabbits/run-active.md"
WAITING="$REPO/.rabbits/run-waiting.md"

# 파일 mtime(epoch초) — GNU stat 우선, 실패하면 BSD stat.
mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo ''
}

# ── 1. 마커 잔존 ────────────────────────────────────────────────────────────
if [ "$IN_RUN" = 1 ]; then
  skip "1. 마커 잔존" "--in-run 지정 — 런 진행 중이므로 마커 존재가 정상이다."
else
  c=''
  [ -e "$ACTIVE" ] && c="$c
.rabbits/run-active.md가 남아 있다 — 단계 6 최종 리포트 출력 후 이 마커를 삭제하고 런을 종료하라."
  [ -e "$WAITING" ] && c="$c
.rabbits/run-waiting.md가 남아 있다 — 대기에서 재개했다면 run-active.md로 되돌리고, 런이 끝났다면 삭제하라."
  report "1. 마커 잔존 — 런 종료 후 마커가 없어야 한다" "$c"
fi

# ── 2. 가드 off 상태 커밋 ───────────────────────────────────────────────────
# run-waiting.md가 있는 동안은 종료 가드가 꺼진다. 그 시점 이후 커밋이 있으면 가드 없이 작업이 진행된 것.
if [ ! -e "$WAITING" ]; then
  skip "2. 가드 off 커밋" "run-waiting.md가 없다 — 과거 대기 구간은 파일로 판정할 수 없다."
else
  c=''
  wt=$(mtime "$WAITING")
  ct=$(git -C "$REPO" log -1 --format=%ct 2>/dev/null || echo '')
  if [ -z "$wt" ] || [ -z "$ct" ]; then
    c="$c
mtime 또는 최신 커밋 시각을 읽지 못했다 (mtime='$wt', commit='$ct')."
  elif [ "$ct" -gt "$wt" ]; then
    c="$c
run-waiting.md 생성 이후($wt) 커밋($ct)이 있다 — 종료 가드가 꺼진 채 작업이 진행됐다.
재개 즉시 run-waiting.md를 run-active.md로 되돌린 뒤 작업하라."
  fi
  report "2. 가드 off 커밋 — 대기 마커 이후 커밋이 없어야 한다" "$c"
fi

# ── 3~4. 최신 런 보고서 검사 ────────────────────────────────────────────────
# 보고서 경로는 .rabbits/config.md의 `# 런 보고서 경로` 섹션이 지정하고, 미지정이면 .rabbits/reports/.
DIR=$(awk '/^# 런 보고서 경로/{f=1;next} f&&/^#/{exit} f&&NF{print;exit}' "$REPO/.rabbits/config.md" 2>/dev/null || echo '')
[ -n "$DIR" ] || DIR="$REPO/.rabbits/reports"
# ponytail: 보고서 루트를 여러 리포가 공유하면 리포명 하위 디렉토리가 실제 보관처다(대소문자 무시 대조).
sub=$(find "$DIR" -maxdepth 1 -type d -iname "$(basename "$REPO")" 2>/dev/null | head -n 1)
[ -n "$sub" ] && DIR="$sub"
LATEST=$(ls -t "$DIR"/*.md 2>/dev/null | head -n 1 || true)

if [ -z "$LATEST" ]; then
  skip "3. 감사 결과 절" "런 보고서를 찾지 못했다: $DIR"
  skip "4. 미해결 절" "런 보고서를 찾지 못했다: $DIR"
else
  # `## 워커 메타` 절의 표에서 워커 행 수 — 헤더 행과 구분선(| --- |)을 뺀 나머지.
  rows=$(awk '
    /^## 워커 메타/ { f=1; next }
    f && /^## / { exit }
    f && /^\|/ {
      probe = $0
      gsub(/[|: \t-]/, "", probe)
      if (probe == "") next   # 구분선
      if (!hdr) { hdr = 1; next }   # 헤더 행
      n++
    }
    END { print n + 0 }
  ' "$LATEST")

  if [ "$rows" -lt 3 ]; then
    skip "3. 감사 결과 절" "$(basename "$LATEST"): 워커 ${rows}명 — 감사 미발동 조건(3명 미만)."
  else
    c=''
    grep -q '^## 감사 결과' "$LATEST" || c="워커 ${rows}명 런인데 '## 감사 결과' 절이 없다 — 독립 감사자를 파견하고
그 판정을 $(basename "$LATEST")에 절로 남겨라."
    report "3. 감사 결과 절 — 워커 3명 이상이면 감사 결과가 있어야 한다" "$c"
  fi

  c=''
  grep -q '^## 미해결' "$LATEST" || c="$(basename "$LATEST")에 '## 미해결' 절이 없다 — 남은 것이 없어도
'## 미해결' 절을 만들고 '없음'이라고 적어라(은폐와 구분하기 위해 절 자체는 필수)."
  report "4. 미해결 절 — 최신 보고서에 미해결 절이 있어야 한다" "$c"
fi

# ── 5. README 드리프트 ──────────────────────────────────────────────────────
# 한글판만 고치고 영문판을 방치해 공개 리포에 거짓 진술이 나간 전례가 있다.
# ponytail: 팀 프리셋 수·아키타입 총계/코어/확장 4종 수치만 대조한다. 산문 대조는 사람 몫.
if [ ! -f "$REPO/README.md" ] || [ ! -f "$REPO/README.en.md" ]; then
  skip "5. README 드리프트" "README.md 또는 README.en.md가 없다 — 대조 대상이 아니다."
else
  c=''
  # $1=파일, $2=sed -E 추출식 → 중복 제거한 숫자들을 공백 하나로 이어 반환.
  nums() { sed -nE "$2" "$1" | sort -u | tr '\n' ' '; }
  for pair in \
    "아키타입 총계|s/^(.*[^0-9])?([0-9]+)종[( =]*코어.*/\2/p|s/^(.*[^0-9])?([0-9]+) (archetypes|total).*/\2/p" \
    "코어 수|s/.*코어 ([0-9]+).*/\1/p|s/^(.*[^0-9])?([0-9]+) core.*/\2/p" \
    "확장 수|s/.*확장 ([0-9]+).*/\1/p|s/^(.*[^0-9])?([0-9]+) extended.*/\2/p" \
    "팀 프리셋 수|s/.*팀 프리셋 ([0-9]+)종.*/\1/p|s/^(.*[^0-9])?([0-9]+) specialist team presets.*/\2/p"
  do
    label=${pair%%|*}; rest=${pair#*|}
    ko=$(nums "$REPO/README.md" "${rest%%|*}")
    en=$(nums "$REPO/README.en.md" "${rest#*|}")
    [ "$ko" = "$en" ] || c="$c
$label 표기 불일치 — README.md='$ko' / README.en.md='$en'. 양쪽을 같은 수치로 맞춰라."
  done
  report "5. README 드리프트 — 한/영 수치 표기가 일치해야 한다" "$c"
fi

# ── 6. 미푸시 커밋 ──────────────────────────────────────────────────────────
if ! git -C "$REPO" rev-parse --abbrev-ref '@{u}' > /dev/null 2>&1; then
  skip "6. 미푸시 커밋" "upstream이 설정돼 있지 않다 — 원격 대조 불가."
else
  c=''
  ahead=$(git -C "$REPO" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '')
  if [ -z "$ahead" ]; then
    c="미푸시 커밋 수를 세지 못했다."
  elif [ "$ahead" != 0 ]; then
    c="원격에 반영되지 않은 커밋이 ${ahead}건이다 — \`git push\`로 반영하고 런을 끝내라."
  fi
  report "6. 미푸시 커밋 — 로컬에만 남은 커밋이 없어야 한다" "$c"
fi

if [ "$FAILED" = 0 ]; then
  echo "== 자기 감사 통과 (FAIL 0) =="
else
  echo "== 자기 감사 FAIL — 위 사유를 확인하라 ==" >&2
fi
exit "$FAILED"
