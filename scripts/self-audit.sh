#!/bin/sh
# rabbits 자기 감사 — 런 종료 직후 대장이 돌려 자기 규약 위반을 기계적으로 잡는다.
# 사용법: sh self-audit.sh [--repo DIR] [--session ID] [--in-run]   (어느 디렉토리에서 호출해도 무방)
#   --repo: 감사할 대상 프로젝트. 생략하면 CLAUDE_PROJECT_DIR, 그것도 없으면 현재 디렉토리의 git 루트.
#           스크립트 위치로 잡으면 다른 프로젝트 런에서 플러그인 리포를 감사하게 된다(보고서 실증).
#   --session: 이번 런의 세션 ID. 런 마커는 .rabbits/runs/<세션>.md 이고 검사 1~4가 이것을 런 레저로 읽는다.
#              마커 본문의 `- 보고서:` 경로가 검사 대상이다.
#   --in-run: 런 진행 중 실행. 마커 잔존 검사(1번)만 건너뛴다.
# 파괴적 동작 없음(조회만 — rm·reset·force·add 미사용). 파일·git 상태로만 판정되는 것만 검사하고,
# 사람 판단이 필요한 것(면제 사유의 타당성, 수치 반올림 여부)은 검사하지 않는다.
# 6검사 각각 PASS/FAIL/SKIP/WARN을 출력하고 하나라도 FAIL이면 비제로 종료.
# 검사 5·6은 rabbits 플러그인 리포 자체를 고치는 런에서만 돈다.
set -eu

REPO=''
SESSION=''
IN_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO=${2-}; shift 2 ;;
    --session) SESSION=${2-}; shift 2 ;;
    --in-run) IN_RUN=1; shift ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -n "$REPO" ] || REPO=${CLAUDE_PROJECT_DIR:-}
[ -n "$REPO" ] || REPO=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO=$(CDPATH= cd -- "$REPO" && pwd)
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

RUNS="$REPO/.rabbits/runs"
# 런 레저 = 이 세션의 마커. 단계 0이 만들고 단계 6이 지운다. 다른 세션 마커는 보지 않는다.
MARKER=''
BLOCKLOG=''
if [ -n "$SESSION" ]; then
  [ -e "$RUNS/$SESSION.md" ] && MARKER="$RUNS/$SESSION.md"
  BLOCKLOG="$RUNS/$SESSION.blocks"
fi

# ── 1. 마커 잔존 ────────────────────────────────────────────────────────────
if [ "$IN_RUN" = 1 ]; then
  skip "1. 마커 잔존" "--in-run 지정 — 런 진행 중이므로 마커 존재가 정상이다."
elif [ -z "$SESSION" ]; then
  others=$(ls "$RUNS"/*.md 2>/dev/null | wc -l | tr -d ' ')
  skip "1. 마커 잔존" "--session 이 없어 이번 런 마커를 특정할 수 없다(runs/ 안 마커 ${others}개)."
else
  c=''
  [ -e "$RUNS/$SESSION.md" ] && c=".rabbits/runs/$SESSION.md 가 남아 있다 — 단계 6 최종 리포트 출력 후 이 마커를 삭제하고 런을 종료하라."
  report "1. 마커 잔존 — 런 종료 후 마커가 없어야 한다" "$c"
fi

# ── 2. 가드 차단 ────────────────────────────────────────────────────────────
# 종료 가드는 기다릴 워커가 없는데 턴을 끝내려 할 때만 막고 그때마다 <세션>.blocks 에 epoch을 남긴다.
# 훅은 하니스가 호출하므로 대장 자기 신고보다 믿을 만한 출처다.
# FAIL이 아니라 WARN인 이유: 차단은 위반의 "실행"이 아니라 이미 막힌 일이라 고쳐서 없앨 수 없다 —
# FAIL로 두면 "게이트 FAIL 0" 조건이 로그 삭제(증거 인멸)를 유도한다. 은폐는 검사 4가 잡는다.
BLOCKS_N=0
if [ -z "$BLOCKLOG" ]; then
  skip "2. 가드 차단" "--session 이 없어 차단 로그를 특정할 수 없다."
elif [ ! -s "$BLOCKLOG" ]; then
  report "2. 가드 차단 — 기다릴 워커 없이 턴을 끝내려 한 적이 없어야 한다" ""
else
  n=$(grep -c '^[0-9]' "$BLOCKLOG" 2>/dev/null || true)
  # 숫자가 아니면 0으로 — set -e 아래에서 `[ "" -gt 0 ]`이 게이트 전체를 죽이지 않게 한다.
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -gt 0 ]; then
    last=$(grep '^[0-9]' "$BLOCKLOG" | tail -n 1)
    warn "2. 가드 차단 — ${n}회(마지막 $last)" "기다릴 워커도 없는데 턴을 끝내려 해 종료 가드가 ${n}회 막았다.
사용자 답이 필요하면 AskUserQuestion 으로 묻고, 일이 남았으면 이어가라.
보고서 '## 미해결'에 '가드 차단 N회'로 적어 드러내라(적으면 검사 4 통과, 숨기면 FAIL)."
    BLOCKS_N="$n"
  else
    report "2. 가드 차단 — 기다릴 워커 없이 턴을 끝내려 한 적이 없어야 한다" ""
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
elif [ "$IN_RUN" = 1 ] && [ -n "$SESSION" ]; then
  # 런 중인데 이 세션 마커가 없다. 최신 보고서로 폴백하면 마커 누락이 가려진다.
  LEDGER_ERR="--in-run 인데 이 세션의 런 마커(.rabbits/runs/$SESSION.md)가 없다 — 단계 0 마커 생성을 빠뜨렸거나
세션 ID 가 다르다. 마커를 만들고 \`- 보고서: <경로>\` 줄을 적어라."
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
  # 검사 2 WARN이 떴는데 보고서가 침묵하면 은폐다 — WARN 단독으로는 아무것도 강제하지 못한다.
  # 신고하면 PASS, 숨기면 FAIL이라 로그를 지울 유인이 생기지 않는다(감사 제안).
  # 검사 3이 아니라 여기 둔 이유: 검사 3은 감사 미발동 런에서 SKIP으로 빠져 은폐 검사가 안 돈다.
  if [ "${BLOCKS_N:-0}" -gt 0 ] && ! grep -q '가드 차단' "$REPORT"; then
    c="$c
검사 2가 가드 차단 ${BLOCKS_N}회를 잡았는데 보고서에 '가드 차단' 언급이 없다 —
'## 미해결'에 몇 회였는지 적어 드러내라(적으면 통과, 숨기면 이 검사가 FAIL이다)."
  fi
  report "4. 미해결 절·가드 차단 신고 — 빠진 것 없이 적어야 한다" "$c"
fi

# ── 5~6. rabbits 플러그인 리포 전용 ─────────────────────────────────────────
# README 한/영 수치와 미푸시 커밋은 플러그인 리포를 고치는 런의 규약이다. 다른 프로젝트 런에 적용하면
# 그 런과 무관한 FAIL이 난다(보고서 실증: 타 프로젝트 런에서 플러그인 리포 미푸시 커밋으로 FAIL).
IS_RABBITS=0
grep -q '"name"[ ]*:[ ]*"rabbits"' "$REPO/.claude-plugin/plugin.json" 2>/dev/null && IS_RABBITS=1

# ── 5. README 드리프트 ──────────────────────────────────────────────────────
# 한글판만 고치고 영문판을 방치해 공개 리포에 거짓 진술이 나간 전례가 있다.
# ponytail: 팀 프리셋 수·아키타입 총계/코어/확장 4종 수치만 대조한다. 산문 대조는 사람 몫.
if [ "$IS_RABBITS" = 0 ]; then
  skip "5. README 드리프트" "대상이 rabbits 플러그인 리포가 아니다 — 대조 대상이 아니다."
elif [ ! -f "$REPO/README.md" ] || [ ! -f "$REPO/README.en.md" ]; then
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
if [ "$IS_RABBITS" = 0 ]; then
  skip "6. 미푸시 커밋·미커밋 변경" "대상이 rabbits 플러그인 리포가 아니다 — 푸시 여부는 그 프로젝트의 정책이다."
elif ! git -C "$REPO" rev-parse --abbrev-ref '@{u}' > /dev/null 2>&1; then
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
  dirty=$(git -C "$REPO" status --porcelain -- skills scripts agents hooks .claude-plugin .gitignore .rabbits/qa-checklist.md README.md README.en.md 2>/dev/null || echo '')
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
