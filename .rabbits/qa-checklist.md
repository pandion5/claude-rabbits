# QA 체크리스트

검증 시나리오 원장 — 기능별 섹션(`## 기능명`), 항목 = `- 시나리오 — 기대 결과`.
순회 결과(✓/✗)는 여기 기록하지 않는다 — 결과는 그 런의 최종 리포트에. 항목 삭제는 기능 제거 시에만.

## 문서 정합성

- 공통 규칙 말미 고정 문구(archetypes.md 공통 규칙 인용문)가 코어8+확장93 워커 템플릿 말미와 축자 일치하는가(`대장은 공통 규칙의 \`rabbits-result\` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.` 문자열을 skills/run/archetypes.md + skills/run/archetypes-ext/*.md에서 카운트. 주의: 선언문은 소스에서 개행에 걸쳐 있어 라인 단위 grep은 누락 — 개행·연속 공백 정규화 후 매치) — 정확히 102건(선언 1 + 템플릿 101), 변형·누락 0건
- README.md 파일 구조 트리에 `.claude-plugin/marketplace.json` 행이 있고 실제 디렉토리와 대응하는가(`grep marketplace.json README.md` + `.claude-plugin/` 실제 파일 목록 대조) — 트리에 marketplace.json·plugin.json 둘 다 나열, 실제 파일 2종과 1:1 일치
- 확장 카탈로그 인덱스(archetypes.md 확장 카탈로그 표) 분야 라벨 12개가 대응 파일 H1에 부분 문자열로 포함되는가(archetypes-ext/*.md H1 12건 추출 후 각 라벨 포함 확인) — 12파일 전부 라벨⊆H1, 포함 불일치 0건
- 인덱스 표 분야별 "(N)" 종수가 해당 archetypes-ext/<파일>.md에 나열된 실제 아키타입 개수와 일치하는가(셀 내 `/` 구분 나열 개수 vs 파일 내 `^## ` 섹션 수 12파일 대조) — 12파일 전부 표기 숫자=실제 수(9/9/9/8/7/10/8/7/6/7/6/7), 총합 93
- 코어+확장 총계 산술이 맞는가(archetypes.md `^## N.` 코어 헤더 수=8, 인덱스 "(N)" 합=93, 8+93=101)와 팀 프리셋 수(teams.md `^## X팀` 헤더 수=5)가 README.md·archetypes.md의 "101종"·"5종" 표기와 일치하는가 — 8+93=101, 팀=5, 총계 수치 불일치 0건
- SKILL.md가 Read 참조하는 경로(단계 2: archetypes.md·archetypes-ext/<분야>.md·teams.md / 단계 4: review-rubric.md)가 실제 skills/run/ 아래 존재하는가(실재 파일 목록과 대조) — 참조 전부 실재, 확장 12파일명도 인덱스 "파일" 컬럼과 1:1 대응
- 팀 프리셋 5종 명칭이 README.md 전문 팀 표·teams.md `## X팀` 헤더·SKILL.md 단계 1 팀 발동표 3곳에서 동일 집합인가(세 위치 팀명 추출 후 3-way 대조) — {테크팀,법무팀,보안팀,서치팀,QA팀} 순서 무관 동일, 철자 불일치 0건
- 코어 아키타입 8종 한글명이 README.md 코어 표와 archetypes.md `## N. 이름 (영문)` 헤더 8개 사이 번호·명칭 모두 일치하는가(번호순 대조) — 8개명 두 위치에서 번호·철자 일치
- 버전 문자열이 리포 활성 영역에서 `.claude-plugin/plugin.json` 단 한 곳에만 선언되는가(plugin.json의 version 값을 읽어 그 문자열을 json·md 전체에서 grep — 이력·인용 성격인 docs/·.superpowers/·이 체크리스트 자신은 제외) — 선언 매치 정확히 1건(plugin.json), 타 파일 버전 재선언 없음
