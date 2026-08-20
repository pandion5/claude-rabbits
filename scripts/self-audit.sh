#!/bin/sh
# rabbits 자기 감사 — 런 종료 직후 대장이 돌려 자기 규약 위반을 기계적으로 잡는다.
# 사용법: sh scripts/self-audit.sh [--in-run]   (어느 디렉토리에서 호출해도 무방)
#   --in-run: 런 진행 중 실행. 마커 잔존 검사(1번)만 건너뛴다.
# 검사 2~4는 런 마커(.rabbits/run-active.md 또는 run-waiting.md)를 런 레저로 읽는다 —
# 마커 본문의 `- 보고서:` 경로가 검사 대상이고, `- 대기:`/`- 재개:` epoch 이력이 대기 구간 근거다.
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

# 경고 — 드러내되 FAILED에는 영향을 주지 않는다(이미 차단된 과거 사건이라 되돌릴 수 없다).
warn() {
  echo "[WARN] $1"
  printf '%s\n' "$2" | sed '/^$/d; s/^/       · /'
}

IN_RUN=0
[ "${1-}" = "--in-run" ] && IN_RUN=1

ACTIVE="$REPO/.rabbits/run-active.md"
WAITING="$REPO/.rabbits/run-waiting.md"

# 런 레저 = 지금 존재하는 마커. 단계 0이 만들고 단계 6이 지우며 대기 전환 시 파일명만 바뀐다.
MARKER=''
[ -e "$ACTIVE" ] && MARKER="$ACTIVE"
[ -e "$WAITING" ] && MARKER="$WAITING"

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
# run-waiting.md가 있는 동안은 종료 가드가 꺼진다. 그 구간의 커밋은 가드 없이 진행된 작업이다.
# 재개하며 run-active.md로 원복하면 파일 증거가 사라지므로, 마커 본문에 누적된
# `- 대기: <epoch>` / `- 재개: <epoch>` 이력을 1순위 근거로 쓴다(원복해도 줄은 남는다).
spans=''
if [ -n "$MARKER" ]; then
  # 대기~재개 쌍을 한 줄씩 출력. 짝 없는 마지막 대기는 지금까지가 구간이다(아직 대기 중).
  spans=$(awk -v now="$(date +%s)" '
    /^- 대기:[ ]*[0-9]/ { sub(/^- 대기:[ ]*/, ""); w = $1 + 0; next }
    /^- 재개:[ ]*[0-9]/ { sub(/^- 재개:[ ]*/, ""); if (w) { print w, $1 + 0; w = 0 } next }
    END { if (w) print w, now }
  ' "$MARKER")
fi

if [ -n "$spans" ]; then
  c=''
  hits=$(git -C "$REPO" log --format=%ct 2>/dev/null | awk -v spans="$(echo "$spans" | tr '
' ';')" '
    BEGIN { n = split(spans, L, ";") }
    { for (i = 1; i <= n; i++) { split(L[i], p, " ")
        if (p[1] != "" && $1 >= p[1] && $1 <= p[2]) { print "커밋 " $1 " (대기 구간 " p[1] "~" p[2] ")"; break } } }
  ' || echo '')
  [ -z "$hits" ] || c="마커 대기 이력과 겹치는 커밋이 있다 — 종료 가드가 꺼진 채 작업이 진행됐다.
$hits
재개 즉시 run-waiting.md를 run-active.md로 되돌린 뒤 커밋하라."
  report "2. 가드 off 커밋 — 마커 대기 구간에 커밋이 없어야 한다" "$c"
elif [ ! -e "$WAITING" ]; then
  skip "2. 가드 off 커밋" "마커에 대기 이력이 없고 run-waiting.md도 없다 — 과거 대기 구간은 판정할 수 없다."
else
  # 폴백: 이력 없는 구형 마커. mtime으로만 판정한다.
  c=''
  wt=$(mtime "$WAITING")
  ct=$(git -C "$REPO" log -1 --format=%ct 2>/dev/null || echo '')
  if [ -z "$wt" ] || [ -z "$ct" ]; then
    c="mtime 또는 최신 커밋 시각을 읽지 못했다 (mtime='$wt', commit='$ct')."
  elif [ "$ct" -gt "$wt" ]; then
    c="run-waiting.md 생성 이후($wt) 커밋($ct)이 있다 — 종료 가드가 꺼진 채 작업이 진행됐다.
재개 즉시 run-waiting.md를 run-active.md로 되돌린 뒤 작업하라."
  fi
  report "2. 가드 off 커밋 — 대기 마커 이후 커밋이 없어야 한다(mtime 폴백)" "$c"
fi

# ── 2보조. 훅 차단 로그 — 마커 레저에 안 남는 "미신고 대기" ────────────
# 대장이 run-waiting.md 개명 없이 턴을 끝내면 정의상 `- 대기:` 줄이 안 남아 검사 2가 못 잡는다.
# 그때마다 Stop hook이 종료를 차단하며 epoch을 남기므로, 훅이 쓴 로그를 보조 근거로 읽는다
# (훅은 하니스가 호출하므로 대장 자기신고인 마커 레저보다 신뢰할 수 있는 출처다).
# 로그가 없거나 비면 구버전이거나 차단이 없었던 것이니 아무 말도 하지 않는다(기존 판정으로 폴백).
# FAIL이 아니라 WARN인 이유: 발동은 위반의 "실행"이 아니라 "차단"이고 이미 지난 일이라 고쳐서
# 없앨 수 없다 — FAIL로 두면 "게이트 FAIL 0" 조건이 로그 삭제(증거 인멸)를 유도한다.
BLOCKLOG="$REPO/.rabbits/run-blocks.log"
if [ -s "$BLOCKLOG" ]; then
  n=$(grep -c '^[0-9]' "$BLOCKLOG" 2>/dev/null || true)
  # 숫자가 아니면 0으로 — set -e 아래에서 `[ "" -gt 0 ]`이 게이트 전체를 죽이지 않게 한다.
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -gt 0 ]; then
    last=$(grep '^[0-9]' "$BLOCKLOG" | tail -n 1)
    c="대기 전환 없이 턴을 끝내 종료 가드가 ${n}회 차단했다 — 마커 레저에는 흔적이 없는 구간이다.
완료알림·사용자 응답을 기다리며 턴을 끝낼 때는 run-active.md → run-waiting.md 개명 + touch +
본문에 '- 대기: <epoch>' append, 재개 즉시 원복 + '- 재개: <epoch>' append하라.
반복되면 보고서 '## 미해결'에 적어 드러내라(로그는 런 종료 후 다음 비런 턴에 훅이 자동으로 비운다)."
    warn "2보조. 미신고 대기 — Stop hook 차단 ${n}회(마지막 $last)" "$c"
  fi
fi

# ── 3~4. 이번 런 보고서 검사 ───────────────────────────────────────────────
# 보고서 경로는 .rabbits/config.md의 `# 런 보고서 경로` 섹션이 지정하고, 미지정이면 .rabbits/reports/.
DIR=$(awk '/^# 런 보고서 경로/{f=1;next} f&&/^#/{exit} f&&NF{print;exit}' "$REPO/.rabbits/config.md" 2>/dev/null || echo '')
[ -n "$DIR" ] || DIR="$REPO/.rabbits/reports"
# ponytail: 보고서 루트를 여러 리포가 공유하면 리포명 하위 디렉토리가 실제 보관처다(대소문자 무시 대조).
sub=$(find "$DIR" -maxdepth 1 -type d -iname "$(basename "$REPO")" 2>/dev/null | head -n 1)
[ -n "$sub" ] && DIR="$sub"

# 검사 대상은 **이번 런** 보고서 — 마커 본문 `- 보고서: <경로>`가 지정한다.
# 최신 파일(ls -t)로 집으면 이번 런이 저장을 통째로 빼먹어도 직전 런 보고서가 대신 통과시킨다.
REPORT=''
LEDGER_ERR=''
if [ -n "$MARKER" ]; then
  rel=$(sed -n 's/^- *보고서: *//p' "$MARKER" 2>/dev/null | head -n 1 | sed 's/[[:space:]]*$//' || echo '')
  if [ -z "$rel" ]; then
    LEDGER_ERR="런 마커($(basename "$MARKER"))에 \`- 보고서: <경로>\` 줄이 없다 — 단계 0 런 레저 규약이다.
마커 본문에 이번 런 보고서 경로를 적어야 게이트가 이번 런을 검사할 수 있다."
  else
    # 절대경로(/… 또는 E:/…)면 그대로, 상대경로면 리포 루트 → 보고서 디렉토리 순으로 찾는다.
    case "$rel" in
      /*|[A-Za-z]:*) cand="$rel" ;;
      *) cand="$REPO/$rel" ;;   # ponytail: DIR은 이미 리포명 하위라 $DIR/$rel은 존재 불가 경로였다
    esac
    if [ -f "$rel" ]; then REPORT="$rel"
    elif [ -f "$REPO/$rel" ]; then REPORT="$REPO/$rel"
    elif [ -f "$DIR/$rel" ]; then REPORT="$DIR/$rel"
    else
      LEDGER_ERR="이번 런 보고서 저장 누락 — 마커가 가리킨 '$rel'이 없다(확인: $cand).
단계 6 '런 보고서 저장'을 마커 삭제 전에 끝내라."
    fi
  fi
else
  # 마커가 없다 = 런 종료 후 무플래그 실행. 이때만 최신 보고서 폴백.
  REPORT=$(ls -t "$DIR"/*.md 2>/dev/null | head -n 1 || true)
fi

if [ -n "$LEDGER_ERR" ]; then
  report "3. 보고서 서식·감사 결과 절 — 이번 런 보고서가 있어야 한다" "$LEDGER_ERR"
  report "4. 미해결 절 — 이번 런 보고서에 미해결 절이 있어야 한다" "$LEDGER_ERR"
elif [ -z "$REPORT" ]; then
  skip "3. 보고서 서식·감사 결과 절" "런 보고서를 찾지 못했다: $DIR"
  skip "4. 미해결 절" "런 보고서를 찾지 못했다: $DIR"
else
  base=$(basename "$REPORT")
  # `## 워커 메타` 절의 표에서 워커 행 수 — 헤더 행과 구분선(| --- |)을 뺀 나머지.
  rows=$(awk '
    /^## 워커 메타/ { f=1; next }
    f && /^## / { exit }
    f && /^\|/ {
      probe = $0
      gsub(/[|: 	-]/, "", probe)
      if (probe == "") { sep = 1; if (first) { first = 0 }; next }   # 구분선
      # 헤더 행은 **구분선이 뒤따를 때만** 소비한다. 무조건 소비하면 헤더 없는 표에서
      # 워커가 1명 적게 세어져 3명 런이 감사 미발동으로 빠져나간다(감사 실증).
      if (!seen1) { seen1 = 1; cand = 1; next }
      if (cand && !sep) { n++ }   # 구분선이 안 왔다 = 첫 행도 워커다
      cand = 0
      n++
    }
    END { print n + 0 }
  ' "$REPORT")
  # 감사 발동 조건은 SKILL 단계 6과 같다: 워커 3명 이상 **또는** 코칭·에스컬레이션 1회 이상.
  # 보고서 관례상 "코칭 N회"/"코칭 N(…)" 형태로 적히므로 첫 등장 수치를 읽되,
  # 범위를 `## 워커 메타` 절 안으로 제한한다 — 파일 전체 첫 일치를 읽으면 '## 감사 결과' 같은 절이
  # 워커 메타 위에 올 때 거기 적힌 "코칭 3회"류가 판정을 뒤집는다(감사 지적).
  coach=$(awk '
    /^## 워커 메타/ { f=1; next }
    f && /^## / { exit }
    f && match($0, /(코칭|에스컬레이션)[ :]*[0-9]+/) {
      s = substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); print s + 0; exit }' "$REPORT")

  c=''
  dormant=0
  if ! grep -qE '^## 워커 메타([[:space:]]|$)' "$REPORT" || [ "$rows" -lt 1 ]; then
    # 서식 미준수를 SKIP으로 넘기면 "표를 안 쓰는 것"이 감사 면제 수단이 된다 — 서식 자체가 규약이다.
    c="$base: '## 워커 메타' 절 또는 그 워커 표가 없다(행 ${rows}) — 보고서 필수 서식이다.
워커명·아키타입·모델·라운드 수·판정 표를 절 아래에 적어라."
  elif [ "$rows" -ge 3 ] || { [ -n "$coach" ] && [ "$coach" -ge 1 ]; }; then
    grep -qE '^## 감사 결과([[:space:]]|$)' "$REPORT" || c="$base: 워커 ${rows}명·코칭 ${coach:-불명}회 런인데 '## 감사 결과' 절이 없다 —
독립 감사자를 파견하고 그 판정을 절로 남겨라(발동 조건: 워커 3명 이상 또는 코칭 1회 이상)."
  elif [ -z "$coach" ]; then
    # 워커 3명 미만인데 코칭 횟수를 못 읽으면 발동 여부 자체가 미정이다 — 조용히 통과시키지 않는다.
    c="$base: 코칭·에스컬레이션 횟수를 읽지 못해 감사 발동 여부를 판정할 수 없다(워커 ${rows}명).
보고서에 '코칭 N회'를 명시하라 — 발동 조건이 워커 수 단독이 아니다."
  else
    dormant=1
  fi
  if [ "$dormant" = 1 ]; then
    skip "3. 보고서 서식·감사 결과 절" "$base: 워커 ${rows}명·코칭 ${coach}회 — 감사 미발동 조건."
  else
    report "3. 보고서 서식·감사 결과 절 — 서식을 갖추고 발동 시 감사 결과가 있어야 한다" "$c"
  fi

  c=''
  # 앵커 뒤 경계 — `## 미해결없음` 같은 유사 제목이 절을 대신 통과시키지 못하게 한다.
  grep -qE '^## 미해결([[:space:]]|$)' "$REPORT" || c="$base에 '## 미해결' 절이 없다 — 남은 것이 없어도
'## 미해결' 절을 만들고 '없음'이라고 적어라(은폐와 구분하기 위해 절 자체는 필수)."
  report "4. 미해결 절 — 이번 런 보고서에 미해결 절이 있어야 한다" "$c"
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
    if [ -z "$ko" ] || [ -z "$en" ]; then
      # 양쪽 다 비면 ko = en이라 통과해버린다 — 추출 실패 자체가 문구 드리프트 신호다.
      c="$c
$label 추출 실패 — README.md='$ko' / README.en.md='$en'. 대조식이 문구를 못 잡는다(드리프트 신호):
표기를 되돌리거나 이 스크립트의 추출식을 새 문구에 맞춰라."
    elif [ "$ko" != "$en" ]; then
      c="$c
$label 표기 불일치 — README.md='$ko' / README.en.md='$en'. 양쪽을 같은 수치로 맞춰라."
    fi
  done
  report "5. README 드리프트 — 한/영 수치 표기가 일치해야 한다" "$c"
fi

# ── 6. 미푸시 커밋 ──────────────────────────────────────────────────────────
if ! git -C "$REPO" rev-parse --abbrev-ref '@{u}' > /dev/null 2>&1; then
  skip "6. 미푸시 커밋·미커밋 변경" "upstream이 설정돼 있지 않다 — 원격 대조 불가."
else
  c=''
  ahead=$(git -C "$REPO" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '')
  if [ -z "$ahead" ]; then
    c="미푸시 커밋 수를 세지 못했다."
  elif [ "$ahead" != 0 ]; then
    c="원격에 반영되지 않은 커밋이 ${ahead}건이다 — \`git push\`로 반영하고 런을 끝내라."
  fi
  # 릴리스 후 제품 파일을 고치고 커밋하지 않으면 rev-list로는 안 잡힌다(감사 실증).
  dirty=$(git -C "$REPO" status --porcelain -- skills scripts agents hooks .rabbits/qa-checklist.md README.md README.en.md 2>/dev/null || echo '')
  [ -n "$dirty" ] && c="$c
미커밋 제품 변경이 남아 있다 — 커밋·푸시하거나 되돌려라:
$dirty"
  report "6. 미푸시 커밋·미커밋 변경 — 로컬에만 남은 것이 없어야 한다" "$c"
fi

if [ "$FAILED" = 0 ]; then
  echo "== 자기 감사 통과 (FAIL 0) =="
else
  echo "== 자기 감사 FAIL — 위 사유를 확인하라 ==" >&2
fi
exit "$FAILED"
