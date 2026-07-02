# Task 6 리포트 — 로컬 설치 + 스모크 실행

## 실행 환경 메모

- `claude --plugin-dir` 경로 인자는 **반드시 따옴표로 감싸야** 한다. Bash(Git Bash) 셸에서
  `E:\2026.Toy\Rabbits`를 따옴표 없이 넘기면 백슬래시가 이스케이프로 소비되어
  `E:2026.ToyRabbits`가 되고, Windows 드라이브 상대경로 규칙 때문에 cwd와 합쳐져
  `E:\2026.Toy\Rabbits\2026.ToyRabbits` 같은 엉뚱한 경로로 해석된다(`Unknown command: /rabbits:run`
  및 `plugin list`의 `Path not found` 로 확인). `"E:\2026.Toy\Rabbits"`처럼 큰따옴표로
  감싸면 정상 로드된다. 스킬 파일 결함은 아니라서 파일은 수정하지 않았고, 이 리포트에만 기록한다.
- 모든 T1~T5는 헤드리스(`-p`)로 실행. 중간 나레이션(팀 로스터, 감독 등) 확인을 위해
  각 T마다 `--verbose --output-format stream-json`으로 1회씩 추가 실행해 이벤트 스트림을
  Node 스크립트로 파싱했다. stream-json에는 메인 세션 이벤트와 서브에이전트(워커) 이벤트가
  `parent_tool_use_id`로 구분되어 함께 흘러나온다는 것을 확인함(둘 다 `type: assistant`라
  구분 없이 보면 워커 산출물을 대장 나레이션으로 착각하기 쉬움 — 파싱 시 주의).

---

## Step 1 — 플러그인 로드 확인

명령:
```
claude --plugin-dir "E:\2026.Toy\Rabbits" -p "/rabbits:run 스모크 로드 확인 — 워커 파견 없이 '로드 OK'라고만 답하라"
```

결과: **통과**. 출력:
```
rabbits 오케스트레이션 시작 — 스모크 로드 확인 (워커 파견 없음)

로드 OK
```
`claude --plugin-dir "..." plugin list`로도 `rabbits@inline / Status: loaded` 확인.
`Unknown skill`/`Unknown command` 없음 — plugin.json·SKILL.md 경로 정상.

---

## Step 2~3 — T1~T5 스모크 실행

### T1 리서치형 (필수 게이트)

명령: `claude --plugin-dir "E:\2026.Toy\Rabbits" -p "/rabbits:run docs/ 아래 문서 구조와 핵심 결정을 조사해 요약 보고해줘" --permission-mode acceptEdits` (+ 관찰용 stream-json 재실행 1회)

Expected 관찰:
- "rabbits 오케스트레이션 시작 —" 시작 선언: **관찰됨** (두 실행 모두)
- 팀 로스터 표 나레이션: **부분 관찰** — 1차 실행(최종 텍스트만)은 W1/W2 두 워커 언급이 있어
  로스터 단계를 거쳤을 것으로 추정되나 중간 텍스트 미확보. 2차 실행(stream-json)은 단일
  워커 케이스라 "규모 파악 먼저"라는 산문 서술로 넘어가고 명시적 표는 생략됨. SKILL.md 단계1은
  워커 수와 무관하게 표를 요구하지만, T2·T4 실행에서는 워커 1명이어도 표가 나왔던 것과 비교하면
  이번 건은 실행별 변동성(non-determinism)으로 판단 — 반복해서 나타나는 패턴이 아니라 SKILL.md는
  수정하지 않음.
- 리서처 워커 파견(Explore 타입), 독립이면 병렬: **관찰됨** — 1차 실행 최종 리포트에 W1
  spec-analyst · W2 plan-analyst(둘 다 Explore/sonnet) 병행 처리 명시. 2차 실행은 워커 1명(Explore)
  단독 파견.
- 중간 사용자 질문 없음(완전 자율): **관찰됨** — 두 실행 모두 헤드리스로 끝까지 자율 완주.
- 최종 리포트 형식(요약/워커별/미해결/통합) 준수: **관찰됨** — 두 실행 모두 요약, 워커별 표,
  미해결 항목, 통합 결과 섹션 전부 포함.

출력 요지: docs/ 스펙+계획 문서 구조, D1~D6 결정 요약, 문서 간 정합성(플랜 T2 표현이 스펙 T2와
다르다는 점까지 스스로 발견해 보고)까지 포함한 고품질 리포트.

**판정: 통과.**

### T2 소코딩

명령: `claude --plugin-dir "E:\2026.Toy\Rabbits" -p "/rabbits:run scripts/greet.ps1을 만들어줘 — 이름 인자를 받아 인사를 출력, 한국어 주석" --permission-mode acceptEdits`

Expected 관찰:
- 구현가→리뷰어 순차 파견: **미관찰(설계상 정상)** — 실제로는 구현가(W1, haiku) 1명만
  파견되고, 검토는 대장이 직접 루브릭으로 수행(별도 리뷰어 워커 없음). SKILL.md 단계4는
  "고위험 산출물(프로덕션 코드 변경, 통합 지점)"에만 독립 리뷰어를 파견하도록 명시하는데,
  신규 토이 스크립트는 고위험으로 분류되지 않아 이 조건에 걸리지 않음 — **프로토콜이 설계대로
  동작한 것**이지 결함이 아님. (참고: `.superpowers/sdd/progress.md`에 이미 README T2가
  스펙 §13 T2의 "리서처→구현가→리뷰어"보다 단순화됐다는 사실이 Task 5 리뷰에서 triage된
  전례가 있음 — 이번 관찰은 그 위에 "리뷰어 파견 자체가 안 걸린다"는 점을 추가 확인한 것.)
- 리뷰어의 독립 검증: 위와 동일 이유로 별도 워커로는 미관찰. 대장 자체검토는 수행됨(완료조건
  대조 + PASS 판정).
- 생성 파일이 2칸 들여쓰기·한국어 주석: **관찰됨** — `scripts/greet.ps1` 생성 확인,
  2칸 들여쓰기·한국어 주석 포함.
- 실행 검증: 워커 자신은 샌드박스 승인 거부로 실제 실행을 못 해 "실행 미확인"으로 정직하게
  보고(BLOCKED은 아니고 PASS 판정 + 미해결 플래그). 리포트 작성자가 직접
  `pwsh -NoProfile -File scripts/greet.ps1 -Name '철수'` / 인자 없이 각각 실행해
  `안녕하세요, 철수님!` / `안녕하세요, 손님님!` 정상 출력·종료코드 0 확인.

**판정: 통과** (스크립트가 스펙대로 정확히 동작. 다만 "구현가→리뷰어" 문구는 저위험
작업에서는 절대 트리거되지 않는 구조 — 결함 아님, README 문구가 최선의 경우를 가정한
낙관적 서술이라는 점만 기록).

### T3 다단계 (병렬)

명령: `claude --plugin-dir "E:\2026.Toy\Rabbits" -p "/rabbits:run 다음 3개를 각각 처리해줘 — (1) README 오탈자 점검 (2) skills/run/SKILL.md 단계 구조 요약 (3) docs/ 스펙의 확정 결정 D1~D6 재검증" --permission-mode acceptEdits`

Expected 관찰:
- 한 메시지에 Agent 호출 3개(병렬): **관찰됨** — stream-json에서 3개의 Agent tool_use가
  전부 동일한 assistant 메시지 ID(`msg_01BqXv7T2KkkGNbistRVbqn3`)에 속함을 확인
  (R1 오탈자 점검/haiku, R2 SKILL.md 구조요약/haiku·Explore, R3 D1~D6 재검증/sonnet·Explore).
- 감독: 전부 foreground(bg=false)로 빠르게 끝나는 잡일 분류라 ScheduleWakeup은 발동하지 않음
  — SKILL.md 단계3.5는 background 워커에만 적용되므로 이는 설계대로다.
- 통합 확인: **관찰됨** — 3개 결과를 표+섹션으로 통합한 최종 리포트 생성.
  실제로 README.md:37 "안되면" 표기 오탈자를 R1이 실제로 찾아냄(→ Step 4에서 수정).

출력 요지: 오탈자 1건(README.md:37), SKILL.md 8단계 구조 요약 표, 스펙 D1~D6 전부 "유효"
판정(불일치 0건).

**판정: 통과.**

### T4 피드백 발동

명령(2회 실행, 재현성 확인차 재시도):
`claude --plugin-dir "E:\2026.Toy\Rabbits" -p "/rabbits:run 좋은 커밋 메시지 가이드 문서를 docs/commit-guide.md로 작성해줘" --permission-mode acceptEdits`

Expected 관찰:
- 최소 1회 REVISE 판정 + SendMessage 코칭 + 재검토 통과: **미관찰** — 2회 실행 모두
  워커(W1, 구현가/sonnet)가 1차 시도에서 곧바로 완료조건을 전부 충족하는 고품질 문서를
  작성했고, 대장 검토가 **1차 PASS**로 끝나 REVISE·SendMessage 코칭이 전혀 트리거되지 않음.
  두 실행 모두 output이 상당히 좋은 품질(7~8개 섹션, 실제 리포 커밋 인용, 좋은/나쁜 예시 등)
  이었음. review-rubric.md·SKILL.md의 REVISE/COACH 로직 자체는 코드 정독으로는 문제없어
  보이나, "완료조건이 일부러 느슨한 작업"이라는 T4의 설계 의도와 달리 sonnet급 구현가가
  아키타입의 "완료조건 자가체크" 요구까지 맞춰 초안부터 통과 수준으로 써내는 경향이 있어,
  현재 문구로는 REVISE 경로를 안정적으로 재현하기 어려움. 이는 헤드리스 하니스 제약이
  아니라 (a) LLM 비결정성 + (b) 워커 품질이 기대보다 높다는 실질적 관찰이므로, SKILL.md는
  **수정하지 않음**(그 자체는 결함이 없음 — 실제 REVISE가 필요한 상황에서는 정상 작동할
  것으로 판단되나, 이번 스모크에서 그 상황을 재현하지 못했다는 뜻).
- SendMessage 코칭: 미관찰(위와 동일 이유).

산출물: `docs/commit-guide.md` (2차 실행분 채택 — 1차 실행분은 재시도를 위해 임시 폴더로
옮겼다가 폐기). 두 산출물 모두 내용 품질은 준수(리포 관례 반영, 좋은/나쁜 예시, 실제 커밋
인용 등).

**판정: 미통과(부분)** — 산출물 자체는 정상이지만, T4가 검증하려던 "REVISE→코칭 루프"
경로는 이번 스모크에서 관측 못 함. README 체크박스는 미체크 상태 유지.

### T5 감독 발동

명령: `claude --plugin-dir "E:\2026.Toy\Rabbits" -p "/rabbits:run 이 리포 전체 문서의 상호참조를 조사해줘 — 조사 워커는 background로 파견하고 제한시간은 1분으로" --permission-mode acceptEdits`

Expected 관찰:
- ScheduleWakeup 장전 나레이션: **관찰됨** — `ScheduleWakeup({delaySeconds:60, reason:"rabbit-A/rabbit-B ... 1분 제한시간 감시", prompt:"rabbits watchdog: ..."})` 호출 확인. 하니스 응답:
  `"Next wakeup scheduled for 11:27:00 (in 113s). Nothing more to do this turn — the harness
  re-invokes you when the wakeup fires or a task-notification arrives."` — 요청한 60초가
  아니라 113초 뒤로 스케줄됨(하니스의 최소 단위/반올림으로 추정). 이후 실제로 세션이
  재기동되는 `system/init` 이벤트가 stream-json에 2회 등장 — **헤드리스에서도 ScheduleWakeup이
  실제로 발동함을 확인**(브리프가 우려한 "헤드리스에서 안 먹을 수 있다"는 이번 실행에서는
  해당하지 않았음).
- T 경과 시 점검(TaskList/TaskGet)·연장 또는 교체 투입: **미관찰** — 두 background 워커
  (rabbit-A 코어문서 9개, rabbit-B sdd문서 12개, 둘 다 Explore/sonnet)가 각각 92초·142초 만에
  스스로 완료 알림을 보냈고, 이는 워치독 웨이크업이 개입을 판단하기 전에 도착해 SKILL.md
  단계3.5의 "완료알림 도착(자동) → 타이머 무시하고 검토로" 정상경로로 처리됨. 실제로
  TaskList/TaskGet/TaskStop 툴 호출은 로그 전체에서 0건(개입이 필요 없었으므로). 연장·교체
  분기를 강제로 재현하려면 워커가 확실히 오래 걸리는 시나리오가 필요한데, 헤드리스에서
  워커 소요시간을 통제하기 어려워 이번 스모크에서는 재현하지 못함 — **하니스가 막아서
  못 본 게 아니라, 타이밍(워커가 예상보다 빨리 끝남)상 개입 분기에 도달하지 못한 것**이라
  정직하게 기록. SKILL.md는 수정하지 않음(로직 자체는 정독 결과 문제없음).

출력 요지: 문서 21개, 참조 지점 약 109건 지도화, 깨진 참조 0건, `agents/` 의도적 부재
3건 모두 정합 확인.

**판정: 부분 관찰** — 장전(정상경로) 확인, 개입경로는 미확인. README 체크박스는 미체크 유지.

---

## Step 4 — 발견 문제와 수정

1. **"안되면" 표기 불일치** (T3 워커 R1이 README.md:37에서 실제 발견, 부수적으로
   review-rubric.md:34/36/38에도 동일 패턴 존재 확인) — "안 되다"(부정+동사, "되지 않다"의 뜻)는
   띄어 써야 하는데 "안되다"(형용사, "안쓰럽다"의 뜻)로 붙여 쓴 오기. **수정함**:
   - `README.md:37` "안되면" → "안 되면"
   - `skills/run/review-rubric.md:34,36,38` (에스컬레이션 사다리 다이어그램 3곳) "안되면" → "안 되면"
   - `docs/superpowers/specs/...` , `docs/superpowers/plans/...` 안의 동일 표기는 **수정하지 않음**
     — 이미 승인/커밋된 스펙·계획 문서이고 Task 6 브리프가 수정 권한을 주는 대상은
     "Task 2~5 산출물"(SKILL.md·archetypes.md·review-rubric.md·README.md)로 한정되어
     범위 밖으로 판단.

2. **T2 "구현가→리뷰어" 문구가 실제로는 트리거 안 됨** — 결함이 아니라 SKILL.md 단계4의
   "고위험 산출물만 독립 리뷰어" 규칙이 정상 작동한 결과(최소 인원 원칙 준수). 리뷰어를
   항상 파견하도록 SKILL.md를 바꾸면 오히려 "과분해 금지" 철칙과 충돌하므로 **수정하지 않음**.
   README 문구가 낙관적이라는 점만 리포트에 기록.

3. **T4 REVISE 경로 미관찰(2회 시도)** — SKILL.md·review-rubric.md 코드 자체의 결함으로
   보이지 않음(정독 결과 로직 정상) — **수정하지 않음**. 실제 REVISE가 필요한 만큼 부실한
   산출물이 나오는 상황을 헤드리스에서 강제 재현하기 어렵다는 한계로 기록.

4. **T5 개입 경로 미관찰** — ScheduleWakeup 자체는 정상 작동(장전·발동·재기동 전부 확인),
   다만 워커가 제한시간보다 빨리 끝나 개입 분기에 도달하지 못함 — **수정하지 않음**.

5. **`claude --plugin-dir` 경로 인용부호 필요** — 하니스/셸 이슈이지 플러그인 파일 결함이
   아니므로 파일은 수정하지 않고 이 리포트 상단에 기록.

## Files changed

- `README.md` — "안되면"→"안 되면" 오탈자 수정, T1~T3 체크박스 `[x]` 반영.
- `skills/run/review-rubric.md` — 에스컬레이션 사다리 다이어그램 3곳 "안되면"→"안 되면" 오탈자 수정.
- `scripts/greet.ps1` (신규, T2 스모크 부산물 — 실제 동작 확인 완료, 커밋 대상)
- `docs/commit-guide.md` (신규, T4 스모크 부산물 — 2차 실행 결과물 채택, 커밋 대상)

## Self-review findings

- README 체크리스트: T1·T2·T3만 `[x]` 처리, T4·T5는 미체크 유지 — T2는 산출물이 정확하고
  검토 루프 자체는 작동했으나 "리뷰어 파견"이라는 문구를 문자 그대로 만족하진 않아 판단이
  갈릴 수 있는 지점. 이유는 위 Step 4·T2 섹션에 명시했으니 최종 사용자가 다르게 판단하면
  체크박스만 조정하면 됨.
- T4는 2회 실행 모두 동일하게 1차 PASS로 끝나 "미관찰"로 결론지었으나, 이는 통계적으로
  약한 근거(n=2)다. 표본을 더 늘리면 REVISE가 관찰될 가능성도 있으나, 헤드리스 실행 비용을
  고려해 2회에서 멈췄다.
- T5의 "113초로 반올림된 스케줄" 관찰은 하니스의 ScheduleWakeup 최소 지연 단위에 대한
  흥미로운 데이터지만, 재현 가능한 규칙인지는 이번 1회 관찰만으로 단정할 수 없다.
- docs/commit-guide.md·scripts/greet.ps1은 둘 다 "스모크 부산물"이며 제품 스펙의 정식
  일부가 아니다 — 커밋에는 포함하되 리포에 명시함.

## 픽스 라운드 1

- **README.md T2 설명 정정**: "구현가→리뷰어 순차 DAG + 검토 루프 확인" → "구현가 파견 + 대장 루브릭 검토 확인(독립 리뷰어 워커는 고위험 산출물에만 별도 파견)" (Step 4·T2 실측 반영)
- **검증**: T1~T5 항목 개수 여전히 5개 확인(pwsh Select-String)
