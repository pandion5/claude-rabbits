#!/bin/sh
# rabbits 릴리스 수순 묶음 — 검증 → 버전 상향 → 선별 스테이징 → 커밋 → push → 플러그인 갱신.
# 사용법: sh scripts/release.sh [--dry-run] <new-version> "<commit subject>" [파일...]
#   파일 목록을 생략하면 이미 스테이징된 목록을 그대로 대상으로 삼는다.
# 파괴적 동작 없음(rm·reset·force 미사용). 검증을 모두 통과한 뒤에만 add를 시작해 부분 커밋을 막는다.
set -eu

# 공통 규칙 말미 고정 문구 — archetypes.md + archetypes-ext/*.md 통틀어 정확히 102건이어야 한다.
PHRASE='대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.'
PHRASE_EXPECTED=102
PLUGIN_JSON='.claude-plugin/plugin.json'

fail() {
  echo "[중단] $1" >&2
  exit 1
}

usage() {
  echo '사용법: sh scripts/release.sh [--dry-run] <new-version> "<commit subject>" [파일...]' >&2
  exit 2
}

DRY_RUN=0
if [ "${1-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi
[ $# -ge 2 ] || usage
VERSION=$1
SUBJECT=$2
shift 2

# 버전 문자열 형식 검증 — sed 치환에 그대로 들어가므로 경계에서 막는다.
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "버전 형식이 잘못됐다: $VERSION (예: 0.20.0)"
[ -n "$SUBJECT" ] || fail "커밋 제목이 비었다."

cd "$(git rev-parse --show-toplevel)"

# 파일 목록 생략 시 스테이징된 목록 채택.
# ponytail: 공백 없는 경로 전제(이 리포 기준). 공백 경로가 생기면 -z + read 루프로 바꿀 것.
if [ $# -eq 0 ]; then
  staged=$(git diff --cached --name-only)
  [ -n "$staged" ] || fail "대상 파일이 없다 — 인자로 파일을 주거나 먼저 git add 하라."
  IFS='
'
  set -- $staged
  unset IFS
fi

echo "== 사전 검증 =="

# ① 현재 브랜치가 main인가
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = "main" ] || fail "현재 브랜치가 main이 아니다: $branch"
echo "  ✓ 브랜치: main"

# ② 런 마커는 절대 커밋 금지 — 대상 목록에 섞였는지 검사
for f in "$@"; do
  case "$f" in
    *run-active.md|*run-waiting.md) fail "런 마커가 대상 목록에 있다: $f (마커는 커밋 금지)" ;;
  esac
done
echo "  ✓ 런 마커 없음"

# ③ README.md 중복 행 검사 — 표 행(`|`)과 노트 항목(`- **`)의 완전 중복(연속·비연속 모두) 검출.
#    수동 재적용 사고(`| QC팀 |` 행 중복, 워크트리 문단 중복) 재발 차단이 목적.
readme=''
for f in "$@"; do
  case "$f" in
    README.md|*/README.md) readme=$f ;;
  esac
done
if [ -n "$readme" ] && [ -f "$readme" ]; then
  dups=$(awk '
    {
      line = $0
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      if (line ~ /^\|/) {
        # 표 구분선(| --- | --- |)은 정상적으로 반복되므로 제외
        probe = line
        gsub(/[|: \t-]/, "", probe)
        if (probe == "") next
      } else if (line !~ /^- \*\*/) {
        next
      }
      if (seen[line]++) printf "    %d행: %s\n", NR, substr(line, 1, 80)
    }
  ' "$readme")
  if [ -n "$dups" ]; then
    echo "$dups" >&2
    fail "$readme 에 중복 행이 있다 — 수동 재적용 중복 사고로 보인다. 위 행을 정리하고 다시 실행하라."
  fi
  echo "  ✓ $readme 중복 행 없음"
fi

# ⑤ 고정 문구 카운트(개행·연속 공백 정규화 후 축자 일치)
count=$(cat skills/run/archetypes.md skills/run/archetypes-ext/*.md \
  | tr '\n\t' '  ' | tr -s ' ' \
  | awk -v p="$PHRASE" '{ n=0; s=$0; while ((i=index(s,p))>0) { n++; s=substr(s, i+length(p)) } print n }')
[ "$count" = "$PHRASE_EXPECTED" ] || fail "고정 문구 카운트가 ${count}건 — ${PHRASE_EXPECTED}건이어야 한다."
echo "  ✓ 고정 문구 ${count}건"

# ④ plugin.json 버전 — 다르면 상향, 같으면 통과. (버전 판정만 검증 단계에서, 실제 쓰기는 검증 통과 후)
cur=$(sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON")
[ -n "$cur" ] || fail "$PLUGIN_JSON 에서 version을 읽지 못했다."
if [ "$cur" = "$VERSION" ]; then
  echo "  ✓ plugin.json 버전 이미 $VERSION"
  BUMP=0
else
  echo "  · plugin.json 버전 $cur → $VERSION 상향 예정"
  BUMP=1
fi

echo "== 검증 통과 =="

# 여기서부터 실제 변경. 버전 상향분은 반드시 같은 커밋에 실려야 하므로 대상 목록에 더한다.
if [ "$BUMP" = "1" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "[드라이런] plugin.json version $cur → $VERSION"
  else
    tmp="${PLUGIN_JSON}.tmp"
    sed 's/\("version"[ ]*:[ ]*\)"'"$cur"'"/\1"'"$VERSION"'"/' "$PLUGIN_JSON" > "$tmp"
    mv "$tmp" "$PLUGIN_JSON"
    echo "  plugin.json version $cur → $VERSION"
  fi
  set -- "$@" "$PLUGIN_JSON"
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "[드라이런] git add $*"
  echo "[드라이런] git commit -m \"$SUBJECT\" -m \"Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>\""
  echo "[드라이런] git push"
  echo "[드라이런] claude plugin update rabbits@rabbits"
  exit 0
fi

git add -- "$@"
git commit -m "$SUBJECT" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
# 플러그인 갱신은 리포 작업 완료 후의 로컬 편의 단계 — 실패해도 커밋·push는 이미 유효하므로 경고만.
claude plugin update rabbits@rabbits || echo "[경고] claude plugin update 실패 — 수동으로 실행하라." >&2
echo "== 릴리스 $VERSION 완료 =="
