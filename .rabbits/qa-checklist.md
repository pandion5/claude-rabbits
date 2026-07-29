# QA 체크리스트

검증 시나리오 원장 — 기능별 섹션(`## 기능명`), 항목 = `- 시나리오 — 기대 결과`.
순회 결과(✓/✗)는 여기 기록하지 않는다 — 결과는 그 런의 최종 리포트에. 항목 삭제는 기능 제거 시에만.

## 문서 정합성

- 공통 규칙 말미 고정 문구(archetypes.md 공통 규칙 인용문)가 코어8+확장93 워커 템플릿 말미와 축자 일치하는가(`대장은 공통 규칙의 \`rabbits-result\` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.` 문자열을 skills/run/archetypes.md + skills/run/archetypes-ext/*.md에서 카운트. 주의: 선언문은 소스에서 개행에 걸쳐 있어 라인 단위 grep은 누락 — 개행·연속 공백 정규화 후 매치) — 정확히 102건(선언 1 + 템플릿 101), 변형·누락 0건
- README.md 파일 구조 트리에 `.claude-plugin/marketplace.json` 행이 있고 실제 디렉토리와 대응하는가(`grep marketplace.json README.md` + `.claude-plugin/` 실제 파일 목록 대조) — 트리에 marketplace.json·plugin.json 둘 다 나열, 실제 파일 2종과 1:1 일치
- 확장 카탈로그 인덱스(archetypes.md 확장 카탈로그 표) 분야 라벨 12개가 대응 파일 H1에 부분 문자열로 포함되는가(archetypes-ext/*.md H1 12건 추출 후 각 라벨 포함 확인) — 12파일 전부 라벨⊆H1, 포함 불일치 0건
- 인덱스 표 분야별 "(N)" 종수가 해당 archetypes-ext/<파일>.md에 나열된 실제 아키타입 개수와 일치하는가(셀 내 `/` 구분 나열 개수 vs 파일 내 `^## ` 섹션 수 12파일 대조) — 12파일 전부 표기 숫자=실제 수(9/9/9/8/7/10/8/7/6/7/6/7), 총합 93
- 코어+확장 총계 산술이 맞는가(archetypes.md `^## N.` 코어 헤더 수=8, 인덱스 "(N)" 합=93, 8+93=101)와 팀 프리셋 수(teams.md `^## X팀` 헤더 수=5)가 README.md의 "101종"·"5종" 표기와 일치하는가 — 8+93=101, 팀=5, 총계 수치 불일치 0건
- SKILL.md가 Read 참조하는 경로(단계 2: archetypes.md·archetypes-ext/<분야>.md·teams.md / 단계 4: review-rubric.md)가 실제 skills/run/ 아래 존재하는가(실재 파일 목록과 대조) — 참조 전부 실재, 확장 12파일명도 인덱스 "파일" 컬럼과 1:1 대응
- 팀 프리셋 5종 명칭이 README.md 전문 팀 표·teams.md `## X팀` 헤더·SKILL.md 단계 1 팀 발동표 3곳에서 동일 집합인가(세 위치 팀명 추출 후 3-way 대조) — {테크팀,법무팀,보안팀,서치팀,QA팀} 순서 무관 동일, 철자 불일치 0건
- 코어 아키타입 8종 한글명이 README.md 코어 표와 archetypes.md `## N. 이름 (영문)` 헤더 8개 사이 번호·명칭 모두 일치하는가(번호순 대조) — 8개명 두 위치에서 번호·철자 일치
- 버전 문자열이 리포 활성 영역에서 `.claude-plugin/plugin.json` 단 한 곳에만 선언되는가(plugin.json의 version 값을 읽어 그 문자열을 json·md 전체에서 grep — 이력·인용 성격인 docs/·.superpowers/·이 체크리스트 자신, 별도 배포 단위인 codex/는 제외) — 선언 매치 정확히 1건(plugin.json), 타 파일 버전 재선언 없음

## Stop hook 종료 가드

- Stop hook 마커 부재/존재 2케이스 계약 — 마커 없으면 stdout 빈 값·exit 0, 마커 있으면 decision=="block"이고 reason 비어있지 않은 유효 JSON·exit 0 (검증: CLAUDE_PROJECT_DIR을 임시 디렉토리로 지정해 `sh hooks/stop-guard.sh` 실행 후 stdout을 `python -c "import json,sys; json.load(sys.stdin)"`로 파싱하고 exit code 확인)
- hooks.json Stop 이벤트 스키마 정합 — hooks.Stop[0].hooks[0].type이 "command"이고 command가 stop-guard.sh를 가리키는 훅이 등록되어 있음 (검증: `python -c "import json; d=json.load(open('hooks/hooks.json',encoding='utf-8')); assert d['hooks']['Stop'][0]['hooks'][0]['type']=='command'"`)
- SKILL.md 마커 생명주기 지시 존재 — 단계 0에 `.rabbits/run-active.md` 생성(Write) 지시, 단계 6에 최종 리포트 후 마커 삭제 지시가 명시되어 하니스 종료 차단을 오케스트레이터가 스스로 해제 가능 (검증: `grep -n "run-active.md" skills/run/SKILL.md`로 단계 0 생성 문맥과 단계 6 삭제 문맥 두 곳 모두 존재하는지 확인)

## 지식베이스 연동

- SKILL.md 단계 1 팩 조립 (d)항에 지식베이스 색인 조건부 주입 지시가 있고 로드 상한·생략 경로가 명시되는가(`grep -n "지식베이스" skills/run/SKILL.md`로 단계1 (d) 라인 확인 + `grep -n "색인 없으면 생략" skills/run/SKILL.md`로 생략 문구, `grep -n "전체 로드 금지" skills/run/SKILL.md`로 단계1 상한 문구 확인) — (d)에 "주입돼 있으면" 조건절, "상위 2~3개...만 Read해(전체 로드 금지)" 상한, "(색인 없으면 생략)" 생략절 모두 존재
- SKILL.md 단계 6에 지식베이스 수확 지시가 마커 삭제보다 앞서 있고 검증 게이트가 명시되는가(`grep -n "지식베이스 수확\|런 마커 삭제" skills/run/SKILL.md`로 두 불릿 라인 번호 비교 + `grep -n "단계 4 PASS 근거\|미검증 추측·1회성 정보는 제외" skills/run/SKILL.md`로 게이트 문구 확인) — 수확 라인 번호 < 마커 삭제 라인 번호, "단계 4 PASS 근거로 확인된" 게이트와 "미검증 추측·1회성 정보는 제외" 배제절 존재

## 워크트리 격리

- 워크트리 격리 발동 조건·옵션명·안전 제약이 skills/run/SKILL.md 단계 3에 명시되어 있는가 — 발동 기준(2명 이상 병렬/위험 단독), `isolation: 'worktree'`, 격리 워커 {{제약}} 주입(cwd=워크트리·상대 해석·밖 쓰기 금지·**완료 시 커밋 의무**), 원장 갱신 격리 금지, 거부 시 무격리 재파견 폴백(`grep -nE "2명 이상을 병렬|isolation: 'worktree'|반드시 커밋|격리 금지|무격리로 재파견" skills/run/SKILL.md`) — 5개 키워드 모두 단계 3 구간에서 검출
- 워크트리 격리 회수·정리가 **단계 4 도입부(검토 전)**에 있고 산출물 소멸 방지 안전선이 명시되어 있는가 — worktreePath·worktreeBranch 회수, `status --porcelain` 빈 값 확인 후에만 `git worktree remove --force`(`grep -nE "회수·정리\(검토 전\)|worktreePath|status --porcelain|git worktree remove --force" skills/run/SKILL.md` + 회수 라인 번호가 단계 4 구간(단계 5 헤더 이전)에 있는지 확인) — 4개 키워드 검출 + 위치 = 단계 4, 단계 6엔 회수 불릿 부재

## Stop hook 대기 규약

- Stop hook 대기 규약이 SKILL.md 단계 3.5에 양방향(개명·원복)으로 존재하고 .gitignore가 두 마커(run-active.md·run-waiting.md)를 모두 커버하는가 — 대기 시작 시 run-active.md→run-waiting.md 개명, 재개 시 run-waiting.md→run-active.md 원복 (검증: 단계 3.5 절 텍스트를 개행·연속 공백 정규화 후 "run-active.md ... run-waiting.md ... 개명" 정규식과 "run-waiting.md ... run-active.md ... 원복" 정규식 각각 매치 확인 + `grep -n "run-active.md\|run-waiting.md" .gitignore`로 두 마커 라인 존재 확인; 추가로 스크래치 임시 디렉토리에 .rabbits/run-waiting.md만 두고 run-active.md는 없는 상태에서 `CLAUDE_PROJECT_DIR=<임시디렉토리> sh hooks/stop-guard.sh` 실행 후 stdout이 빈 값이고 exit 0인지 확인 — 대기 중 가드가 정상 통과함을 실측) — 양방향 정규식 매치, .gitignore 2줄, 가드 무출력·exit 0

## 백로그 규약

- SKILL.md 단계 0에 백로그 채택 규약 4요소(무인자 조건·최상단 미완료·나레이션·사용자 요청 폴백)가 모두 존재하는가(`grep -n "backlog.md\|최상단 미완료 1개\|나레이션\|기존대로 사용자에게 작업만 요청" skills/run/SKILL.md`로 단계 0 구간에 무인자 트리거·최상단 1개 채택·"n번째/총 m건" 나레이션·폴백 4개 문구 매치 확인) — 4요소 전부 단계 0 구간 내 존재, 누락 0건
- SKILL.md 단계 6에 체크→연쇄(마커 유지)→소진/상한 시만 삭제 순서와 실패 표기·연쇄 상한이 있는가(`grep -n "백로그 처리\|런 마커 삭제" skills/run/SKILL.md`로 두 불릿 라인 번호 비교 + `grep -n "미해결: 사유\|연쇄는 한 호출당 최대 10건\|백로그가 비었거나" skills/run/SKILL.md`로 실패 표기·상한·종료 조건 확인) — 백로그 처리 라인 < 마커 삭제 라인, 실패 표기(`- [x] 항목 (미해결: 사유 1구)`)·상한 10건·"비었거나 연쇄 상한" 종료 조건 3문구 존재
