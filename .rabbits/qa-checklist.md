# QA 체크리스트

검증 시나리오 원장 — 기능별 섹션(`## 기능명`), 항목 = `- 시나리오 — 기대 결과`.
순회 결과(✓/✗)는 여기 기록하지 않는다 — 결과는 그 런의 최종 리포트에. 항목 삭제는 기능 제거 시에만.

## 문서 정합성

- 공통 규칙 말미 고정 문구(archetypes.md 공통 규칙 인용문)가 코어8+확장93 워커 템플릿 말미와 축자 일치하는가(`대장은 공통 규칙의 \`rabbits-result\` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.` 문자열을 skills/run/archetypes.md + skills/run/archetypes-ext/*.md에서 카운트. 주의: 선언문은 소스에서 개행에 걸쳐 있어 라인 단위 grep은 누락 — 개행·연속 공백 정규화 후 매치) — 정확히 102건(선언 1 + 템플릿 101), 변형·누락 0건
- README.md 파일 구조 트리에 `.claude-plugin/marketplace.json` 행이 있고 실제 디렉토리와 대응하는가(`grep marketplace.json README.md` + `.claude-plugin/` 실제 파일 목록 대조) — 트리에 marketplace.json·plugin.json 둘 다 나열, 실제 파일 2종과 1:1 일치
- 확장 카탈로그 인덱스(archetypes.md 확장 카탈로그 표) 분야 라벨 12개가 대응 파일 H1에 부분 문자열로 포함되는가(archetypes-ext/*.md H1 12건 추출 후 각 라벨 포함 확인) — 12파일 전부 라벨⊆H1, 포함 불일치 0건
- 인덱스 표 분야별 "(N)" 종수가 해당 archetypes-ext/<파일>.md에 나열된 실제 아키타입 개수와 일치하는가(셀 내 나열 개수 vs 파일 내 `^## ` 섹션 수 12파일 대조 — 분할자는 반드시 " / "(공백 포함): `/`만 쓰면 "CI/CD 파이프라인 엔지니어" 때문에 infra-ops가 9로 오검출) — 12파일 전부 표기 숫자=실제 수(9/9/9/8/7/10/8/7/6/7/6/7), 총합 93
- 코어+확장 총계 산술이 맞는가(archetypes.md `^## N.` 코어 헤더 수=8, 인덱스 "(N)" 합=93, 8+93=101)와 팀 프리셋 수(teams.md `^## X팀` 헤더 수=6)가 README.md의 "101종"·"6종" 표기와 일치하는가 — 8+93=101, 팀=6, 총계 수치 불일치 0건
- SKILL.md가 Read 참조하는 경로(단계 2: archetypes.md·archetypes-ext/<분야>.md·teams.md / 단계 4: review-rubric.md)가 실제 skills/run/ 아래 존재하는가(실재 파일 목록과 대조) — 참조 전부 실재, 확장 12파일명도 인덱스 "파일" 컬럼과 1:1 대응
- 팀 프리셋 6종 명칭이 README.md 전문 팀 표·teams.md `## X팀` 헤더·SKILL.md 단계 1 팀 발동표 3곳에서 동일 집합인가(세 위치 팀명 추출 후 3-way 대조) — {테크팀,법무팀,보안팀,서치팀,QA팀,QC팀} 순서 무관 동일, 철자 불일치 0건
- 코어 아키타입 8종 한글명이 README.md 코어 표와 archetypes.md `## N. 이름 (영문)` 헤더 8개 사이 번호·명칭 모두 일치하는가(번호순 대조) — 8개명 두 위치에서 번호·철자 일치
- 버전 문자열이 리포 활성 영역에서 `.claude-plugin/plugin.json` 단 한 곳에만 선언되는가(plugin.json의 version 값을 읽어 그 문자열을 json·md 전체에서 grep — 이력·인용 성격인 docs/·.superpowers/·이 체크리스트 자신·README 스모크 체크리스트의 이력 버전 표기(Tn 라벨), 별도 배포 단위인 codex/는 제외) — 선언 매치 정확히 1건(plugin.json), 타 파일 버전 재선언 없음

## Stop hook 종료 가드

- Stop hook 마커 부재/존재 2케이스 계약 — 마커 없으면 stdout 빈 값·exit 0, 마커 있으면 decision=="block"이고 reason 비어있지 않은 유효 JSON·exit 0 (검증: CLAUDE_PROJECT_DIR을 임시 디렉토리로 지정해 `sh hooks/stop-guard.sh` 실행 후 stdout을 `python -c "import json,sys; json.load(sys.stdin)"`로 파싱하고 exit code 확인)
- hooks.json Stop 이벤트 스키마 정합 — hooks.Stop[0].hooks[0].type이 "command"이고 command가 stop-guard.sh를 가리키는 훅이 등록되어 있음 (검증: `python -c "import json; d=json.load(open('hooks/hooks.json',encoding='utf-8')); assert d['hooks']['Stop'][0]['hooks'][0]['type']=='command'"`)
- SKILL.md 마커 생명주기 지시 존재 — 단계 0에 `.rabbits/run-active.md` 생성(Write) 지시, 단계 6에 최종 리포트 후 마커 삭제 지시가 명시되어 하니스 종료 차단을 오케스트레이터가 스스로 해제 가능 (검증: `grep -n "run-active.md" skills/run/SKILL.md`로 단계 0 생성 문맥과 단계 6 삭제 문맥 두 곳 모두 존재하는지 확인)

## 지식베이스 연동

- 지식베이스 조건부 주입 규약이 실재하고 SKILL에 발동 조건·Read 지시가 잔류하는가(라우터화 반영) — SKILL.md 단계 1에 "지식베이스 색인이 주입돼 있거나" 조건절 + `context-sources.md` Read 지시가 있고, 상세 3요소("주입돼 있으면" 조건·"상위 2~3개…(전체 로드 금지)" 상한·"(색인 없으면 생략)" 생략절)는 `skills/run/context-sources.md`에서 확인 (검증: `grep -c "context-sources.md" skills/run/SKILL.md` ≥1 + `grep -cE "주입돼 있으면|전체 로드 금지|색인 없으면 생략" skills/run/context-sources.md` = 3 — 전체 로드 금지는 context-sources.md 한정 검색으로 archetypes-ext 문맥 오탐 차단)
- SKILL.md 단계 6에 지식베이스 수확 지시가 마커 삭제보다 앞서 있고 검증 게이트가 명시되는가(`grep -n "지식베이스 수확\|런 마커 삭제" skills/run/SKILL.md`로 두 불릿 라인 번호 비교 + `grep -n "단계 4 PASS 근거\|미검증 추측·1회성 정보는 제외" skills/run/SKILL.md`로 게이트 문구 확인) — 수확 라인 번호 < 마커 삭제 라인 번호, "단계 4 PASS 근거로 확인된" 게이트와 "미검증 추측·1회성 정보는 제외" 배제절 존재

## 워크트리 격리

- 워크트리 격리 규약이 실재하고 SKILL 단계 3에 발동 조건·Read 지시가 잔류하는가(라우터화 반영) — SKILL.md 단계 3 구간에 "2명 이상을 병렬" 발동 기준 + `worktree.md` Read 지시(두 문구 합산 2건 이상), 상세 5키워드(`isolation: 'worktree'`·반드시 커밋·격리 금지·무격리로 재파견·환경 스킬/CLI 우선)는 `skills/run/worktree.md`에서 확인 (검증: SKILL 단계 3 구간에서 `grep -cE "2명 이상을 병렬|worktree\.md"` ≥2 + `grep -cE "isolation: 'worktree'|반드시 커밋|격리 금지|무격리로 재파견" skills/run/worktree.md` ≥4)
- 워크트리 회수·정리가 단계 4 도입부(검토 전)에 위치하고 절차 상세가 형제 파일에 실재하는가(라우터화 반영) — SKILL.md에 "격리 워커 회수·정리(검토 전)" 불릿이 단계 4 구간(단계 5 헤더 이전)에 있고 단계 6엔 회수 불릿 부재, 절차 3요소(worktreePath·`status --porcelain`·`git worktree remove --force`)는 `skills/run/worktree.md`에서 확인 (검증: `grep -n "회수·정리(검토 전)" skills/run/SKILL.md` 라인이 단계 4 구간 내 + `grep -cE "worktreePath|status --porcelain|git worktree remove --force" skills/run/worktree.md` = 3)

## Stop hook 대기 규약

- Stop hook 대기 규약이 SKILL.md 단계 3.5에 양방향(개명·원복)으로 존재하고 .gitignore가 두 마커(run-active.md·run-waiting.md)를 모두 커버하는가 — 대기 시작 시 run-active.md→run-waiting.md 개명, 재개 시 run-waiting.md→run-active.md 원복 (검증: 단계 3.5 절 텍스트를 개행·연속 공백 정규화 후 "run-active.md ... run-waiting.md ... 개명" 정규식과 "run-waiting.md ... run-active.md ... 원복" 정규식 각각 매치 확인 + `grep -n "run-active.md\|run-waiting.md" .gitignore`로 두 마커 라인 존재 확인; 추가로 스크래치 임시 디렉토리에 .rabbits/run-waiting.md만 두고 run-active.md는 없는 상태에서 `CLAUDE_PROJECT_DIR=<임시디렉토리> sh hooks/stop-guard.sh` 실행 후 stdout이 빈 값이고 exit 0인지 확인 — 대기 중 가드가 정상 통과함을 실측) — 양방향 정규식 매치, .gitignore 2줄, 가드 무출력·exit 0

## 백로그 규약

- 백로그 채택 규약이 실재하고 SKILL 단계 0에 트리거·Read 지시가 잔류하는가(라우터화 반영) — SKILL.md 단계 0에 "작업이 비어 있으면 `.rabbits/backlog.md`" 트리거 + `backlog.md` Read 지시, 채택 4요소(무인자 조건·최상단 미완료 1개·n/m 나레이션·사용자 요청 폴백)는 `skills/run/backlog.md`에서 확인 (검증: SKILL 단계 0 구간에 backlog.md 참조 ≥1 + `grep -cE "최상단 미완료 1개|기존대로 사용자에게 작업만 요청" skills/run/backlog.md` = 2)
- 백로그 처리가 마커 삭제보다 앞서고 소비·연쇄 규약이 형제 파일에 실재하는가(라우터화 반영) — SKILL.md에서 "백로그 처리" 라인 < "런 마커 삭제" 라인이고 종료 조건("백로그가 비었거나")이 SKILL에 잔류, 실패 표기(`- [x] 항목 (미해결: 사유 1구)`)·연쇄 상한 10건은 `skills/run/backlog.md`에서 확인 (검증: `grep -n "백로그 처리\|런 마커 삭제" skills/run/SKILL.md` 라인 번호 비교 + `grep -cE "미해결: 사유|최대 10건" skills/run/backlog.md` = 2)

## QC팀 프리셋

- teams.md QC팀 섹션에 핵심 요소가 전부 존재하는가 — 감사 전용 경계(외부·기존 한정+tiebreak), 실행 리포 원장, 표준 제약 3종, HITL(`grep -nE "감사 전용|외부·기존|tiebreak|실행(\(작업\))? 리포|qc-checklist\.md|읽기전용|파괴적 액션 금지|ToolSearch 선로드|2회 재현|HITL" skills/run/teams.md`로 QC팀 섹션(`## QC팀` 헤더~파일 끝 또는 다음 헤더) 구간 내 매치 확인) — 10개 키워드 전부 QC팀 섹션 구간에서 검출
- SKILL.md 발동표 QC 행이 외부·기존 산출물로 한정되고 런 산출물 QA 경로가 명시돼 있는가(`grep -n "QC팀" skills/run/SKILL.md`로 발동표 행 확인 + 그 행에 "외부·기존"과 "QA/일반 검토 경로" 포함 여부 확인) — 발동표에 QC팀 행 존재, 두 문구 모두 포함

## 워크트리 생성 우선 규칙

- 워크트리 생성 소프트 우선 규칙 3요소가 형제 파일에 실재하는가(라우터화 반영) — ①환경 스킬/CLI 로드 시 우선 ②버전 매칭 가이드 조회·추측 호출 금지 ③미제공/실패 시 `isolation: 'worktree'` 폴백이 `skills/run/worktree.md`에 전부 존재하고, SKILL.md 단계 3엔 발동 조건 + `worktree.md` Read 지시가 잔류 (검증: `grep -cE "환경 스킬/CLI가 로드돼 있으면 그 방식을 우선|버전 매칭 가이드를 조회해 사용하고\(추측 호출 금지\)|isolation: 'worktree'.*방식으로 폴백" skills/run/worktree.md` = 3)

## 플렉스 모드

- 플렉스 모드 조항이 SKILL.md 단계 2(편성)에 3요소로 명시돼 있는가 — 단계 2 헤더 구간 안에서 발동 조건(지시 또는 세션 컨텍스트 상시 선언)·효과(티어 배정 무시, 전 워커 opus)·기본값(명시 없으면 기본 티어) 3개 패턴이 모두 1건 이상 매칭 (skills/run/SKILL.md에서 `awk '/^## 단계 2/{f=1} /^## 단계 3/{f=0} f'`로 구간을 잘라 `tr -d '\n'`으로 평탄화한 뒤 `grep -c`로 `플렉스 모드.*지시했거나 세션 컨텍스트.*상시 선언` / `티어 배정을 무시하고 전 워커를 .opus.로 파견` / `명시가 없으면 기본 티어` 3패턴 각각 검사 — 모두 ≥1이면 통과, 행 번호 비종속)

## 2축 분리 리뷰

- SKILL.md 단계 4 구간에 2축 리뷰 발동 조건·축 이름·Read 지시가 잔류하는가(라우터화 반영) — "독립 리뷰어 2명 병렬 파견"·"Standards 축"·"Spec 축"·`review-rubric.md` Read 지시·"저위험 산출물은 미발동" 5요소가 각 1건 이상, 상세(축별 루브릭 매핑·병합 금지·판정 결합)는 review-rubric.md에서 확인 (검증: `awk '/^## 단계 4/{f=1;next} f&&/^## /{exit} f' skills/run/SKILL.md | tr '
' ' ' | grep -oE "독립 리뷰어 2명 병렬 파견|Standards 축|Spec 축|review-rubric\.md|저위험 산출물은 미발동" | sort -u | wc -l` = 5)
- review-rubric.md에 "## 2축 분리 리뷰" 절이 존재하고 그 구간 안에 축↔루브릭 매핑과 판정 결합 규칙이 명시돼 있다 — Standards=5·4, Spec=1·2·3, "한 축이라도 미달이면 그 축 사유로 REVISE"가 각 1건씩 총 3건 (검증: `awk '/^## 2축 분리 리뷰/{f=1;next} /^## /{f=0} f' skills/run/review-rubric.md | tr '\n' ' ' | grep -oE 'Standards 축\*\* = 루브릭 \*\*5·4|Spec 축\*\* = 루브릭 \*\*1·2·3|판정 결합.{0,60}REVISE' | wc -l` 결과가 3)

## 사전 스코프 계약

- archetypes.md 공통 규칙 절에 공통 슬롯 6종 선언·"제외범위 준수"·"durability(썩지 않는 서술)" 3요소가 모두 존재한다 — 슬롯 토큰 6종 전원(컨텍스트/작업/제약/완료조건/출력형식/제외범위), 규칙 마커 5종(공통 슬롯 6종·제외범위 준수·durability·줄 번호·evidence) 전원 등장 (`SEC=$(awk '/^## 공통 규칙/{f=1;next} f&&/^## /{exit} f' skills/run/archetypes.md | tr '\n' ' '); echo "$SEC" | grep -oE '\{\{(컨텍스트|작업|제약|완료조건|출력형식|제외범위)\}\}' | sort -u | wc -l` = 6, `echo "$SEC" | grep -oE '공통 슬롯 6종|제외범위 준수|durability|줄 번호|evidence' | sort -u | wc -l` = 5)
- SKILL.md 단계 2(편성) 구간에 `{{제외범위}}`가 조립 슬롯으로 포함돼 있다 — 단계 2 구간 안에서 조립 슬롯 6종이 모두 나타나고 `{{제외범위}}`가 1회 이상 등장 (`SEC=$(awk '/^## 단계 2 /{f=1;next} f&&/^## /{exit} f' skills/run/SKILL.md | tr '\n' ' '); echo "$SEC" | grep -oE '\{\{(컨텍스트|작업|제약|완료조건|출력형식|제외범위)\}\}' | sort -u | wc -l` = 6, `echo "$SEC" | grep -oE '\{\{제외범위\}\}' | wc -l` >= 1)

## 리포별 설정

- 리포별 config 조건부 로드 3요소가 형제 파일에 실재하는가(라우터화 반영) — "있으면 Read"·"전역 기본값 대체"·"없으면 생략+대장 임의 생성 금지"가 `skills/run/context-sources.md`에 전부 존재하고, SKILL.md 단계 1엔 "`.rabbits/config.md`가 있으면" 조건절 + `context-sources.md` Read 지시가 잔류 (검증: **개행 정규화 필수** — `tr '
' ' ' < skills/run/context-sources.md | grep -oE "config\.md.{0,10}있으면 Read|전역 기본값을 \*\*대체\*\*한다|없으면 생략, 대장이 임의 생성하지 *않는다" | sort -u | wc -l` = 3. 라인 단위 grep은 "임의 생성하지 / 않는다"가 줄바꿈에 걸려 2/3만 잡힘 + SKILL.md에 context-sources.md 참조 ≥1)
- 코드 표준의 config 대체 우선순위가 두 파일에 모두 명시돼 있는가 — SKILL.md "## 코드 산출물 표준" 절과 archetypes.md "## 공통 규칙" 절 각 구간에서 config.md 우선/대체 문구가 1회 이상 매칭돼 적중 파일 수 2 (검증: 각 파일을 `awk -v h='^## <헤더>' '$0~h{fl=1;next} fl&&/^## /{exit} fl' <파일> | tr '\n' ' ' | grep -oE 'config\.md.{0,40}(대체한다|우선\*\*한다)' | wc -l` ≥1 인 파일 수 세기 → 2)

## 진단 피드백 루프 사다리

- 디버거 아키타입 템플릿에 진단 피드백 루프 사다리가 규정되어 있는가 — `skills/run/archetypes.md`의 `## 7. 디버거` 구간 안에 사다리 6단계 마커(①~⑥) 6개가 모두 있고, "위에서부터 가능한 첫 수단"·"가설 단계로 진행 금지"·"outcome: BLOCKED"·"need:"·"임시 계측·디버그 코드 전량 제거"·"self_check" 6종 키워드가 전부 존재한다 (검증: `S=$(awk '/^## 7\. 디버거/{f=1;print;next} f&&/^## /{exit} f' skills/run/archetypes.md | tr '\n' ' '); L=$(printf '%s' "$S" | grep -oE '①|②|③|④|⑤|⑥' | wc -l); K=$(printf '%s' "$S" | grep -oE '위에서부터 가능한 첫 수단|가설 단계로 진행 금지|outcome: BLOCKED|need:|임시 계측·디버그 코드 전량 제거|self_check' | sort -u | wc -l); [ "$L" -eq 6 ] && [ "$K" -eq 6 ] && echo PASS || echo FAIL` → `PASS`)

## SKILL 라우터화

- SKILL.md 라우터화 후 분리된 3기능(워크트리 격리·백로그 규약·지식베이스/리포별 설정)의 발동 조건 1줄과 형제 파일 Read 지시가 각각 잔류하는가 — 기능 키워드 3종(`워크트리 격리`/`백로그`/`지식베이스|\.rabbits/config\.md`)이 각 1회 이상 매치되고, 형제 파일명 3종(worktree.md/backlog.md/context-sources.md)이 각 1회 이상 매치되며 그 행에 `Read`가 동행한다 (검증: `cd skills/run`에서 각 f∈{worktree,backlog,context-sources}에 대해 ``grep -E "(^|[^/])\`${f}\.md\`" SKILL.md | grep -c Read`` ≥1, 기능 키워드는 `grep -cE` ≥1 — 경로접두 배제 패턴으로 `.rabbits/backlog.md` 오탐 차단)
- 신설 3파일이 실재하고 비어있지 않으며 SKILL.md가 참조하는 경로와 정확히 일치하는가 — skills/run/{worktree,backlog,context-sources}.md가 각각 존재·크기>0이고, SKILL.md의 형제 참조 3건이 실파일과 1:1 대응 (검증: 각 f에 대해 ``test -s skills/run/$f.md && grep -cE "(^|[^/])\`$f\.md\`" skills/run/SKILL.md``가 참조≥1·실재 yes로 3쌍 모두 성립)

## 런 속도 규칙

- 런 속도 규칙 3종이 단계 3(파견) 구간에 명시되는가 — 분할 기준 수치(20항목/3분)·전용 스크래치 또는 담당 범위·테스터 동시 파견·과분할 경고(고정비) 4요소가 각각 1건 이상 매칭, 다른 단계 구간에서는 0건 (`S=$(awk -v h="^## 단계 3 — 파견" '$0 ~ h {p=1;next} /^## /{p=0} p' skills/run/SKILL.md | tr '\n' ' '); for P in '20\s*항목|3\s*분' '스크래치|담당\s*범위' '테스터' '과분할|고정비'; do printf '%s ' "$(printf '%s' "$S" | grep -oE "$P" | wc -l)"; done` → 4개 카운트 모두 ≥1이면 PASS)

## 릴리스 파이프라인

- scripts/release.sh가 실재하고 사전 검증 5종·드라이런·안전 규칙이 구현돼 있는가 — 파일 존재 + ①브랜치 main 확인 ②마커(run-active/run-waiting) 스테이징 차단 ③README 중복 행 검출 ④plugin.json 버전 검사 ⑤고정 문구 102 카운트 5종이 본문에 나타나고 `--dry-run` 분기 존재, 파괴적 명령(`rm -rf`·`reset --hard`·`push --force`·`push -f`·`clean -fd`)은 0건 (검증: `test -f scripts/release.sh` 후 `grep -cE "main|run-active|seen\[|version|102"` 각 ≥1 — 중복 검출은 awk seen[] 구현(uniq -d 아님) + `grep -nE 'rm -rf|reset --hard|push --force|push -f|clean -fd' scripts/release.sh` 무출력)
- 릴리스 스크립트가 드라이런에서 실제 검증을 수행하고 리포를 변경하지 않는가 — `sh scripts/release.sh --dry-run <현재버전> "test" README.md` 실행 시(**파일 인자 필수** — 없고 스테이징도 비면 "대상 파일이 없다"로 EXIT=1) 5검증 결과를 출력하고 EXIT=0, plugin.json version은 실행 전후 동일 (검증: 실행 전후 `grep version .claude-plugin/plugin.json` 비교 + `git status --porcelain` 신규 변경 0건)

## 행위 검증

- 정적 문자열 검사가 아니라 실제 동작이 계약대로인가 — `sh scripts/behavior-check.sh` 1회 실행으로 3사이클이 전부 `[PASS]`이고 EXIT=0 (①마커 사이클: 임시 프로젝트에 `.rabbits/run-active.md`를 두면 stop-guard가 `decision=block`·비어있지 않은 `reason`·exit 0, `run-waiting.md`로 개명하면 무출력·exit 0(대기 규약), 삭제하면 무출력·exit 0 ②백로그 소비: 미완료 3건 중 최상단 1건만 `- [x]`로 바뀌어 잔여 2건, 미해결 케이스는 `- [x] 항목 (미해결: 사유)` 형식, 대상 외 행은 원문 대조로 바이트 불변 ③릴리스 가드: `release.sh --dry-run <현재버전> "..." README.md`가 EXIT=0, 대상에 `.rabbits/run-active.md`를 섞으면 "런 마커가 대상 목록에 있다"로 EXIT≠0). 임시물은 `mktemp -d` 하위에만 만들고 trap으로 정리하므로 실행 후 `git status --porcelain` 신규 변경 0건

## 리포트 독립 감사

- SKILL.md 단계 6에 리포트 독립 감사 규칙이 최종 리포트 뒤·수확 앞에 있고 4요소가 명시되는가 — 발동 조건(워커 3명+ 또는 코칭·에스컬레이션 1회+)·감사 4항목(미해결 은폐/근거 왜곡/판정 정합/백로그·마커)·읽기전용 하드제약(대신 고치지 말 것)·치명·중요 시 재출력+수정 사실 명시가 각 1건 이상, 위치는 "최종 리포트" 라인 < "리포트 독립 감사" 라인 < "지식베이스 수확" 라인 (검증: `S=$(awk '/^## 단계 6/{f=1;next} f&&/^## /{exit} f' skills/run/SKILL.md | tr '\n' ' '); printf '%s' "$S" | grep -oE '워커 3명 이상|미해결 은폐|근거 왜곡|판정 정합|읽기전용|대신[[:space:]]*고치지 말 것|재출력' | sort -u | wc -l` ≥6 + `grep -n "최종 리포트:\|리포트 독립 감사\|지식베이스 수확" skills/run/SKILL.md` 라인 번호 오름차순)
