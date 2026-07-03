# rabbits 아키타입 확장 5종 + QA팀 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 아키타입 5종(통합가·디버거·검증가·문서가·마이그레이터, 9→14종) + QA팀(영속 QA리스트·전량 순회) 추가, 0.3.0 릴리스.

**Architecture:** 실행 코드 없음. 아키타입 5종은 `archetypes.md` 끝에 추가(공통 규칙 상속, 경계 명문화는 해당 템플릿 안에 — 서처/리서처 전례), QA팀은 `teams.md` 끝에 추가(기존 4팀 무변경), SKILL.md는 정확히 2줄(단계 1 요약표 QA팀 행 + 단계 6 통합가 참조). TDD 대신 **편집 → 검증(Grep/validate) → 커밋** 사이클.

**Tech Stack:** Markdown 문서 + plugin.json. 검증은 Grep/Read + `claude plugin validate`. 커밋은 한국어 Conventional Commits.

## Global Constraints

- 언어: 문서·주석·커밋 전부 한국어. 변수·식별자만 영어.
- 들여쓰기: 2칸.
- 커밋 메시지 말미 트레일러 2줄:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3`
- 스펙 준수: `docs/superpowers/specs/2026-07-03-rabbits-archetypes-qa-design.md` 확정 결정 A1~A8.
- A2: 기존 팀 4종(테크·법무·보안·서치) 편성 무변경. A3: SKILL.md 변경은 정확히 2줄.
- T7 승계: review-rubric.md·SKILL.md 단계 4 수정 금지.
- **펜스 함정**: 마크다운 불릿 안 코드펜스는 상대 3칸까지 — 신규 템플릿 펜스는 탑레벨(들여쓰기 0).
- 신규 아키타입 5종의 말미 고정 문구는 기존 9종과 **글자 단위로 동일**:
  `잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 \`rabbits-result\` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.`
- 스코프 밖 파일 변경 금지. 실행 코드 생성 금지.

---

### Task 1: archetypes.md — 신규 아키타입 5종 추가 (9종 → 14종)

**Files:**
- Modify: `skills/run/archetypes.md` (파일 끝, `## 9. 서처` 섹션 뒤)

**Interfaces:**
- Consumes: 공통 규칙 `rabbits-result` 블록 필드, 기존 `{{도메인}}` 역할 슬롯 전례.
- Produces: 아키타입 명칭 5종 — **통합가 (Integrator)** · **디버거 (Debugger)** · **검증가 (Verifier)** · **문서가 (Doc Writer)** · **마이그레이터 (Migrator)**, 신규 역할 슬롯 `{{독자}}`(문서가 전용). Task 2(teams.md QA팀)·Task 4(README)가 명칭을 그대로 참조.

- [ ] **Step 1: 파일 끝 확인**

Read `skills/run/archetypes.md` — 마지막 섹션이 `## 9. 서처 (Searcher)`임을 확인. 신규 5종은 그 뒤에 이어 붙인다.

- [ ] **Step 2: 아키타입 10·11·12 (통합가·디버거·검증가) 추가**

파일 끝에 추가:

````
## 10. 통합가 (Integrator)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet (무거움 opus)

```
너는 통합가다. 여러 워커의 산출물을 병합·충돌 해소해 최종 결과물로 조립한다 —
통합 대상 산출물만 취급하고, 신규 기능 추가·시키지 않은 리팩토링은 금지.
충돌을 임의로 뭉개지 말 것 — 해소 불가면 BLOCKED로 반환하라.

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}}
완료조건: {{완료조건}}
코드 표준: 2칸 들여쓰기, 한국어 주석, 리포 관례 준수.

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=통합 결과물(또는
위치) + 병합 결정 목록(채택/기각/수정, 각 근거 1줄), evidence=충돌 지점별 해소 근거
file:line, notes=통합에서 버린 것 1줄(있으면).
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```

## 11. 디버거 (Debugger)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet (난해 opus)

```
너는 {{도메인}} 디버거다. 재현→최소화→가설→계측→수정 순서로만 움직인다 —
근본원인을 확정하기 전에는 수정 금지(증상 패치 금지). 재현이 안 되면 추측으로
고치지 말고 BLOCKED로 반환하라. 수정 후에는 원 재현 절차로 미재현을 확인한다.
(경계: 구현가는 스펙대로 새로 작성하고, 디버거는 원인 규명 후 최소 수정한다 —
버그 수정형 작업은 디버거 몫.)

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 원인과 무관한 파일 변경 금지)
완료조건: {{완료조건}}
코드 표준: 2칸 들여쓰기, 한국어 주석, 리포 관례 준수.

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=근본원인 1~2줄 +
수정 요약, evidence=재현 절차·계측 결과·수정 지점 file:line, self_check에
"수정 후 원 재현 절차 미재현 확인" 항목 필수.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```

## 12. 검증가 (Verifier)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet

```
너는 검증가다. 산출물을 실제로 실행해 동작을 관찰한다 — 판정 근거 수집만,
어떤 파일도 수정 금지. 관찰하지 않은 것을 통과로 보고하지 않는다 — 실행 못 한
시나리오는 "미실행"으로 명시하라. (경계: 테스터는 테스트 코드를 작성·실행하고,
검증가는 완성 산출물의 실제 플로우를 구동해 관찰한다.)

컨텍스트: {{컨텍스트}}
작업: {{작업}} (검증 시나리오 목록 포함)
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=시나리오별 관찰
결과(통과/실패/미실행), evidence=시나리오별 실행 명령 + 출력 발췌, notes=미실행
사유 1줄(있으면).
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```
````

- [ ] **Step 3: 아키타입 13·14 (문서가·마이그레이터) 추가**

이어서 추가:

````
## 13. 문서가 (Doc Writer)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet (잡일 haiku)
- 역할 슬롯 `{{독자}}`(대상 독자)를 추가로 쓴다.

```
너는 문서가다. {{독자}}를 위한 문서를 작성·개정한다 — 문서 파일만 수정하고
코드는 변경 금지. 독자에 맞는 깊이·용어를 선택하고, 코드 관점 나열이 아니라
독자의 목적 순서로 구성하라.

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 문서 파일 외 수정 금지)
완료조건: {{완료조건}}
문서 표준: 한국어, 리포 관례 준수.

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=문서 위치 +
구성 요약(섹션 골자), evidence=핵심 구성 결정(독자·구조 선택) 근거, notes=다루지
않은 범위 1줄(있으면).
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```

## 14. 마이그레이터 (Migrator)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet (잡일 haiku)

```
너는 마이그레이터다. 반복 패턴 일괄 변환(rename·API 교체·포맷 통일)을 수행한다 —
변환 규칙 밖 리팩토링 금지. 전수성 의무: 대상 전수 조사 → 변환 → 잔존 0 확인
(검색 증거)까지가 한 사이클이다. 애매한 케이스는 임의 변환하지 말고 notes에 보고하라.

컨텍스트: {{컨텍스트}}
작업: {{작업}} (변환 규칙 명시)
제약: {{제약}} (추가로: 변환 규칙 밖 파일·패턴 변경 금지)
완료조건: {{완료조건}}
코드 표준: 2칸 들여쓰기, 한국어 주석, 리포 관례 준수.

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=변환 규칙 요약 +
변환 파일 수 집계, evidence=잔존 검색 명령 + 0건 결과, notes=제외·애매 케이스 1줄
(있으면).
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```
````

- [ ] **Step 4: 검증 — 14종 + 말미 문구 + 경계·규율 문구**

Run: `Grep pattern="^## [0-9]" path="skills/run/archetypes.md" output_mode="content"`
Expected: 14줄 (1.리서처 ~ 14.마이그레이터).

Run: `Grep pattern="너의 결과 블록이 곧 산출물이다" path="skills/run/archetypes.md" output_mode="count"`
Expected: 공통 규칙 1회 + 템플릿 14회 = 15.

Run: `Grep pattern="증상 패치 금지|미실행|\{\{독자\}\}|전수성 의무|충돌을 임의로 뭉개지" path="skills/run/archetypes.md" output_mode="count"`
Expected: 5개 패턴 전부 1회 이상.

- [ ] **Step 5: 커밋**

```bash
git add skills/run/archetypes.md
git commit -m "$(cat <<'EOF'
feat: 아키타입 5종 추가 — 통합가·디버거·검증가·문서가·마이그레이터

9→14종. 전부 공통 규칙 상속. 경계 명문화 2건(검증가↔테스터, 디버거↔구현가,
A5)을 서처/리서처 전례대로 템플릿 안에 기재. 문서가는 {{독자}} 역할 슬롯
신설(A4), 마이그레이터는 전수성 의무(잔존 0 검색 증거) 규율.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 2: teams.md — QA팀 추가 (5번째 팀)

**Files:**
- Modify: `skills/run/teams.md` (파일 끝, `## 서치팀` 섹션 뒤)

**Interfaces:**
- Consumes: Task 1의 검증가·디버거 + 기존 테스터 아키타입 명칭.
- Produces: **QA팀** 명칭과 발동 신호 — Task 3(SKILL.md 요약표)이 1줄 요약 참조. QA리스트 규약(`.rabbits/qa-checklist.md`).

- [ ] **Step 1: 파일 끝 확인**

Read `skills/run/teams.md` — 마지막 섹션이 `## 서치팀 — 멀티모달 조달 (단독 + 타팀 지원)`임을 확인.

- [ ] **Step 2: QA팀 섹션 추가**

파일 끝에 추가:

```markdown
## QA팀 — 기능 검증·회귀 (영속 QA리스트)

- **발동 신호**: 기능 구현이 포함된 런(구현 산출물 PASS 후·통합 전에 투입),
  "QA 돌려줘"·회귀 점검 성격 요청.
- **QA리스트 규약**: 작업 대상 리포의 `.rabbits/qa-checklist.md`(git 추적). 없으면
  첫 투입 시 생성. 내용 = 검증 시나리오 원장 — 기능별 섹션(`## 기능명`), 항목 =
  `- 시나리오 — 기대 결과`. **순회 결과(✓/✗)는 리스트에 기록하지 않는다**(낡은 ✓가
  "검증됨"으로 오독되는 부패 방지) — 결과는 그 런의 최종 리포트에. 항목 삭제는
  기능 제거 시에만.
- **편성**: 테스터 1 (QA 설계 — 신규 기능의 검증 시나리오를 결과 블록으로 반환,
  **리스트 파일 반영은 대장이 수행**: 테스터 하드제약 "테스트 파일 외 수정 금지"와의
  충돌 방지) + 검증가 1~N (전량 순회 — 리스트가 작으면 1명 순차, 크면 분할 병렬,
  워커 상한 내) + 디버거 0~N (실패 항목 — **발견 시만** 투입). 모델: sonnet.
- **흐름**: 테스터 시나리오 반환 → 대장 리스트 반영 → 검증가 **전량 순회**(신규+기존
  전부 실제 실행·관찰) → 실패 항목을 디버거가 근본원인 수정 → 해당 항목 재검증.
  수정 코드는 고위험 산출물 — 단계 4 규칙대로 독립 리뷰어 교차검증.
- **판정 기준**: 신규 기능 항목이 리스트에 추가됐는가, 전량 순회가 실제 실행됐는가
  (항목별 실행 증거, "미실행" 0), 실패 항목이 수정·재검증 통과했는가.
```

- [ ] **Step 3: 검증 — 팀 5종 + QA 필수 요소**

Run: `Grep pattern="^## " path="skills/run/teams.md" output_mode="content"`
Expected: 6줄 — 공통 원칙 + 테크팀·법무팀·보안팀·서치팀·QA팀.

Run: `Grep pattern="qa-checklist|전량 순회|리스트 파일 반영은 대장" path="skills/run/teams.md" output_mode="count"`
Expected: 3개 패턴 전부 1회 이상.

기존 4팀 무변경 확인:
Run: `git diff --stat HEAD -- skills/run/teams.md`
Expected: teams.md 1파일, 순수 추가만(기존 행 삭제 0 — diff에 `-` 행이 헤더 외 없음).

- [ ] **Step 4: 커밋**

```bash
git add skills/run/teams.md
git commit -m "$(cat <<'EOF'
feat: QA팀 신설 — 영속 QA리스트 + 전량 순회 회귀 체크

5번째 팀. QA리스트는 작업 대상 리포의 .rabbits/qa-checklist.md(시나리오
원장, 결과 비기록 — 부패 방지, A6). 테스터가 시나리오 반환·대장이 리스트
반영(하드제약 충돌 방지), 검증가 전량 순회(규모 적응, A7), 실패 시 디버거.
기존 팀 4종 무변경(A2).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 3: SKILL.md — 정확히 2줄 (요약표 QA팀 행 + 단계 6 통합가 참조)

**Files:**
- Modify: `skills/run/SKILL.md` (단계 1 요약표 57행 부근 + 단계 6 149행 부근)

**Interfaces:**
- Consumes: Task 2의 QA팀 발동 신호, Task 1의 통합가 명칭.

- [ ] **Step 1: 단계 1 요약표에 QA팀 행 추가**

기존(57행):
```
  | 서치팀 | 조사·자료 조달이 핵심 작업일 때, 타팀·타워커가 외부 자료 필요할 때 |
```
바로 아래에 삽입:
```
  | QA팀 | 기능 구현이 포함된 런(구현 PASS 후·통합 전), "QA 돌려줘"·회귀 점검 요청 |
```

- [ ] **Step 2: 단계 6 통합가 참조 정밀화**

기존(149행):
```
  통합이 무거우면 opus 통합 워커에 위임 가능(그 결과도 단계 4로 검토).
```
교체 후:
```
  통합이 무거우면 통합가 아키타입 워커에 위임 가능(opus, 그 결과도 단계 4로 검토).
```

- [ ] **Step 3: 검증 — 2줄 변경뿐인지 + 단계 4·루브릭 무변경**

Run: `Grep pattern="QA팀|통합가 아키타입" path="skills/run/SKILL.md" output_mode="content"`
Expected: 두 지점 매치 (QA팀 요약표 행, 단계 6 통합가).

Run: `git diff --numstat HEAD -- skills/run/SKILL.md`
Expected: `2 1 skills/run/SKILL.md` (추가 2, 삭제 1 — 행 1개 삽입 + 행 1개 교체).

Run: `git diff --stat HEAD -- skills/run/review-rubric.md`
Expected: 출력 없음(무변경).

- [ ] **Step 4: 커밋**

```bash
git add skills/run/SKILL.md
git commit -m "$(cat <<'EOF'
feat: SKILL.md에 QA팀 발동 신호 + 통합가 참조 (2줄)

단계 1 요약표에 QA팀 행, 단계 6의 익명 "opus 통합 워커"를 통합가
아키타입으로 연결(A3 — 상주 변경 최소). 단계 4·review-rubric.md 무변경.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 4: README.md — 14종·5팀 반영

**Files:**
- Modify: `README.md` (34행 단계 2 행, 48행 전문 팀 표, 62~63행 파일 구조)

**Interfaces:**
- Consumes: Task 1(14종)·Task 2(QA팀) 명칭·수치.

- [ ] **Step 1: 동작 방식 표 단계 2 행 갱신**

기존(34행):
```
| 2 | 편성 | 아키타입 9종 + 전문 팀 프리셋 4종(테크·법무·보안·서치) + 모델·제한시간 배정 |
```
교체 후:
```
| 2 | 편성 | 아키타입 14종 + 전문 팀 프리셋 5종(테크·법무·보안·서치·QA) + 모델·제한시간 배정 |
```

- [ ] **Step 2: 전문 팀 표에 QA팀 행 추가**

기존(48행):
```
| 서치팀 | 웹+코드 멀티모달 조달, 타팀 지원 |
```
바로 아래에 삽입:
```
| QA팀 | 기능 검증·회귀 — 영속 QA리스트(.rabbits/qa-checklist.md) 전량 순회 |
```

- [ ] **Step 3: 파일 구조 블록 갱신**

기존(62~63행):
```
│   ├── archetypes.md     # 워커 역할 템플릿 9종
│   ├── teams.md          # 전문 팀 프리셋 4종 (테크·법무·보안·서치)
```
교체 후:
```
│   ├── archetypes.md     # 워커 역할 템플릿 14종
│   ├── teams.md          # 전문 팀 프리셋 5종 (테크·법무·보안·서치·QA)
```

- [ ] **Step 4: 검증**

Run: `Grep pattern="아키타입 14종|전문 팀 프리셋 5종|qa-checklist" path="README.md" output_mode="count"`
Expected: 3개 패턴 전부 1회 이상.

Run: `Grep pattern="아키타입 9종|프리셋 4종" path="README.md" output_mode="count"`
Expected: 0 (옛 수치 잔존 없음).

- [ ] **Step 5: 커밋**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: README에 아키타입 14종·QA팀 반영

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 5: 0.3.0 릴리스 — version 상향 + validate + 전역 반영

**Files:**
- Modify: `.claude-plugin/plugin.json` (version 필드, 4행)

**Interfaces:**
- Consumes: Task 1~4 완료분 전체.

- [ ] **Step 1: version 0.2.0 → 0.3.0**

기존(4행):
```json
  "version": "0.2.0",
```
교체 후:
```json
  "version": "0.3.0",
```

- [ ] **Step 2: 매니페스트 검증**

Run: `claude plugin validate "E:\2026.Toy\Rabbits"`
Expected: 검증 통과(오류 0). SKILL.md 프론트매터 `name` 부재 경고는 기지 무해 — 실패 아님.

- [ ] **Step 3: 커밋**

```bash
git add .claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
chore: 버전 0.3.0 — 아키타입 14종 + QA팀 릴리스

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

- [ ] **Step 4: 전역 캐시 갱신**

Run: `claude plugin update rabbits@rabbits`
Expected: 0.3.0 갱신 메시지. 실패 시 Step 3 커밋 반영 여부 먼저 확인.

- [ ] **Step 5: 갱신 확인**

Run: `claude plugin list`
Expected: `rabbits` 0.3.0 표기.

---

## 자기검토 결과

**1. 스펙 커버리지 (§7 매트릭스 대조):** archetypes 5종+경계 2건(§4) → Task 1 / teams.md QA팀(§5, A6·A7 규약 포함) → Task 2 / SKILL.md 2줄(§6) → Task 3 / README(§7) → Task 4 / 0.3.0+validate+전역(§9) → Task 5. 실런 스모크(§9)는 배포 후 정성 관찰 — 플랜 태스크 아님(전례 동일).

**2. 플레이스홀더 스캔:** 모든 편집 스텝에 삽입/교체 전문 포함. TBD 없음.

**3. 명칭 정합성:** 아키타입 명칭(통합가/디버거/검증가/문서가/마이그레이터)이 Task 1 정의 = Task 2 QA팀 편성(검증가·디버거·테스터) = Task 3 단계 6(통합가) = Task 4 README 수치에서 일치. QA팀 발동 신호 문구가 Task 2(teams.md 상세) = Task 3(요약표 행)에서 정합. `{{독자}}` 슬롯은 Task 1 문서가 전용 — 다른 태스크 참조 없음(정상). 검증 Expected 수치 재계산: 섹션 14, 말미 문구 15(공통 1+템플릿 14), teams `^## ` 6(공통 원칙+팀 5).
