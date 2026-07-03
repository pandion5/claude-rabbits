# rabbits 전문 팀 프리셋 4종 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** rabbits에 테크·법무·보안·서치 4개 전문 팀을 프리셋으로 추가한다 — 아키타입 5→9종, teams.md 신설, SKILL.md 팀 자동판단 통합, 0.2.0 릴리스.

**Architecture:** 실행 코드 없음. 전문 아키타입 4종은 `archetypes.md`에 추가(공통 규칙 상속), 팀 편성·흐름·판정은 `teams.md`에 분리(하이브리드 C안, T5). SKILL.md에는 발동 신호 요약표만 상주하고 상세는 팀 매칭 시 지연 로드(토큰 최소화). TDD 대신 **편집 → 검증(Grep/validate) → 커밋** 사이클.

**Tech Stack:** Markdown 문서 + plugin.json. 검증은 Grep/Read + `claude plugin validate`. 커밋은 한국어 Conventional Commits.

## Global Constraints

- 언어: 문서·주석·커밋 전부 한국어. 변수·식별자만 영어.
- 들여쓰기: 2칸.
- 커밋 메시지 말미 트레일러 2줄:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3`
- 스펙 준수: `docs/superpowers/specs/2026-07-03-rabbits-teams-design.md`의 확정 결정 T1~T7.
- T2: 발동은 대장 자동판단만 — 별도 진입점·스킬 만들지 않는다.
- T3: 보안팀 = 점검 + 패치 (방어 전용). 공격 코드·익스플로잇 금지 문구 필수.
- T5: 아키타입 4종은 archetypes.md, 편성·흐름·판정은 teams.md — 서로 침범 금지.
- T7: review-rubric.md 절대 수정 금지. SKILL.md 단계 4도 수정 금지.
- **펜스 함정**: 마크다운 불릿 안 코드펜스는 상대 3칸 들여쓰기까지만 인식된다.
  신규 아키타입 템플릿의 펜스는 기존 5종처럼 **탑레벨(들여쓰기 0)**에 둔다.
- 신규 아키타입 4종의 말미 고정 문구는 기존 5종과 **글자 단위로 동일**해야 한다:
  `잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 \`rabbits-result\` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.`
- 스코프 밖 파일 변경 금지. 실행 코드 생성 금지.

---

### Task 1: archetypes.md — 신규 아키타입 4종 추가 (5종 → 9종)

**Files:**
- Modify: `skills/run/archetypes.md` (파일 끝, 기획가 섹션 133행 뒤에 추가)

**Interfaces:**
- Consumes: 공통 규칙의 `rabbits-result` 블록 필드(`outcome`/`deliverable`/`evidence`/`self_check`/`notes`).
- Produces: 아키타입 명칭 4종 — **테크 검토가 (Tech Assessor)** · **라이선스 감사가 (License Auditor)** · **보안 감사가 (Security Auditor)** · **서처 (Searcher)**. Task 2(teams.md)·Task 3(SKILL.md)이 이 명칭을 그대로 참조한다.

- [ ] **Step 1: 파일 끝 확인**

Read `skills/run/archetypes.md` — 마지막 섹션이 `## 5. 기획가 (Planner)`(117~133행)임을 확인한다. 신규 4종은 그 뒤에 이어 붙인다.

- [ ] **Step 2: 아키타입 6·7 (테크 검토가·라이선스 감사가) 추가**

파일 끝에 추가:

````
## 6. 테크 검토가 (Tech Assessor)

- 기본 subagent_type: `Explore`(스파이크 필요 시 `claude`) / 기본 모델: sonnet (어려움 opus)

```
너는 {{도메인}} 기술 가능성 검토가다. 실현 가능성을 판정한다 — 판정에는 반드시
근거(문서·코드·실험 결과)를 첨부한다. 기본은 읽기전용. 검증에 스파이크 코드가 꼭
필요할 때만 최소량 작성하되 산출물로 남기지 않는다(스코프 밖 파일 변경 금지).

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}}
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=가능성 판정
(가능/조건부/불가) + 근거 요약 + 핵심 리스크·대안, evidence=근거별 출처
(문서·file:line·실험 결과), notes=판정 확신도 1줄.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```

## 7. 라이선스 감사가 (License Auditor)

- 기본 subagent_type: `Explore` / 기본 모델: sonnet

```
너는 라이선스 감사가다. 의존성 라이선스를 식별하고 호환성·상업적 사용 가능성을
검토한다 — 읽기전용, 파일 수정 금지. 판정은 라이선스 원문 조항 근거로만 한다
(통념·추측 금지). 보고 말미에 "이 검토는 법률 자문이 아니다" 고지를 반드시 포함한다.

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=의존성별
라이선스 + 위험등급(안전/주의/위험) 요약, evidence=위험등급별 근거 조항
(라이선스명·조항), notes="이 검토는 법률 자문이 아니다" 고지 + 총평 1줄.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```
````

- [ ] **Step 3: 아키타입 8·9 (보안 감사가·서처) 추가**

이어서 추가:

````
## 8. 보안 감사가 (Security Auditor)

- 기본 subagent_type: `Explore` / 기본 모델: sonnet

```
너는 {{도메인}} 보안 감사가다. 방어 목적의 취약점 점검만 한다 — 읽기전용, 파일 수정
금지, 공격 코드·익스플로잇 작성 금지. 스캔 범주: 인젝션·하드코드 비밀·의존성 CVE·
설정 미스. 비밀값을 발견해도 원문을 결과에 옮기지 않는다(위치만 보고).

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=발견 요약
(심각도순), evidence=발견별 `위치: [심각도(치명/중요/사소)] 문제. 수정 제안.`,
notes=스캔 커버리지(4범주 중 커버한 것) 1줄.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```

## 9. 서처 (Searcher)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) — WebSearch·WebFetch 필요 / 기본 모델: sonnet (잡일 haiku)

```
너는 서처다. 웹(WebSearch·WebFetch)과 코드(Grep·Glob)를 가로지르는 조달 전문 —
특정 자료·원문·문서를 빨리 찾아 출처와 함께 반환한다. 읽기전용, 파일 수정 금지.
분석·해석은 최소화한다. 경계: 서처는 넓은 조달(자료를 찾아온다), 리서처는 깊은
조사·분석(질문에 답을 만든다).

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=조달물 목록
(항목별 핵심 1줄), evidence=항목별 출처(URL 또는 file:line) + 확신도(높음/중간/낮음),
notes=못 찾은 것·검색 한계 1줄.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```
````

- [ ] **Step 4: 검증 — 9종 존재 + 말미 문구 9회 + 방어 전용·고지 문구 확인**

Run: `Grep pattern="^## [0-9]" path="skills/run/archetypes.md" output_mode="content"`
Expected: 9줄 (1.리서처 ~ 9.서처).

Run: `Grep pattern="너의 결과 블록이 곧 산출물이다" path="skills/run/archetypes.md" output_mode="count"`
Expected: 공통 규칙 1회 + 템플릿 9회 = 10.

Run: `Grep pattern="공격 코드·익스플로잇 작성 금지|법률 자문이 아니다|스파이크|넓은 조달" path="skills/run/archetypes.md" output_mode="count"`
Expected: 4개 패턴 모두 1회 이상 매치.

- [ ] **Step 5: 커밋**

```bash
git add skills/run/archetypes.md
git commit -m "$(cat <<'EOF'
feat: 전문 아키타입 4종 추가 — 테크 검토가·라이선스 감사가·보안 감사가·서처

아키타입 5→9종. 전부 공통 규칙(rabbits-result 블록·반환 예산·팩 존중) 상속.
보안 감사가는 방어 전용(공격 코드 금지·비밀 원문 비전사), 라이선스 감사가는
법률 자문 아님 고지 필수, 서처는 리서처와 조달/조사 경계를 명문화(T5).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 2: teams.md 신설 — 팀 프리셋 4종

**Files:**
- Create: `skills/run/teams.md`

**Interfaces:**
- Consumes: Task 1의 아키타입 명칭(테크 검토가·라이선스 감사가·보안 감사가·서처) + 기존 구현가·리뷰어.
- Produces: 팀 명칭 4종(**테크팀·법무팀·보안팀·서치팀**)과 팀별 발동 신호 — Task 3(SKILL.md 요약표)이 이 발동 신호를 1줄씩 요약해 참조한다. 팀 라벨 규칙 `rabbits:팀/역할: 작업 요약`.

- [ ] **Step 1: teams.md 작성**

`skills/run/teams.md`를 아래 내용 전체로 생성:

```markdown
# 팀 프리셋 라이브러리

대장이 단계 2(편성)에서 팀 매칭된 서브작업이 있을 때 읽는다. 각 팀 항목 =
**발동 신호 · 편성표(아키타입 조합 + 기본 인원 + 모델) · 팀 흐름 · 판정 기준**.

## 공통 원칙

- 팀 = 편성 레시피(문서 계약)다. 상주 조직이 아니다 — 워커는 여전히 즉석 일회용으로
  편성되며, 팀 워커도 일반 워커와 동일하게 단계 3~5(파견·감독·검토·코칭)를 탄다.
- 편성 인원은 **기본값**이다. 대장이 작업 규모로 조절한다 — 최소 인원 원칙과
  워커 상한 12(→18)를 팀이 잠식하지 않는다.
- 팀별 판정 기준은 대장이 단계 4에서 **완료조건 해석의 보조**로 쓴다
  (review-rubric.md 공통 루브릭의 대체가 아니다).
- 모든 조율은 대장 경유 — 팀 간·워커 간 직접 통신 없음.
- 팀 소속 워커 라벨: `rabbits:팀/역할: 작업 요약`
  (예: `rabbits:보안팀/스캐너: 인증 모듈 취약점 스캔`).

## 테크팀 — 기술적 가능성 검토

- **발동 신호**: "기술적으로 가능한가?" 판단, 기술 스택 선택, 아키텍처 결정, 신기술 도입.
- **편성**: 테크 검토가 1~3 (2명 이상이면 독립 각도 분담 — 예: 성능·호환성·구현복잡도)
  + 서처 0~1 (기술 문서·벤치마크 조달 필요 시). 모델: sonnet, 판정 어려우면 opus.
- **흐름**: 병렬 검토 → 대장이 판정 종합. 검토가 간 결론 충돌 시 3번째 검토가 투입
  또는 opus 상향(사다리 2단계 준용).
- **판정 기준**: 판정(가능/조건부/불가)에 근거가 있는가, 리스크·대안이 실행 가능한
  수준으로 구체적인가.

## 법무팀 — 라이선스·상업적 사용 검토

- **발동 신호**: 라이선스 검토, 상업적 사용 가능성, 의존성 도입 판단, 배포·판매 전 점검.
- **편성**: 라이선스 감사가 1 + 서처 0~1 (라이선스 원문·판례 조달 필요 시). 모델: sonnet.
- **흐름**: 의존성 인벤토리 → 라이선스 식별 → 호환성·상업 사용 판정 → 보고서.
- **판정 기준**: 의존성 커버리지가 전수인가, 위험등급(안전/주의/위험)마다 근거 조항이
  있는가, "법률 자문 아님" 고지가 있는가.

## 보안팀 — 취약점 점검 + 패치 (방어 전용)

- **발동 신호**: 보안 점검 요청, 인증·입력처리·비밀 취급 코드 작업, 배포 전 점검.
- **편성**: 보안 감사가(스캐너) 1~2 + 구현가(대응가 = 구현가 아키타입 + 패치 브리프)
  0~N — **발견이 나왔을 때만** 투입. 모델: sonnet, 치명 패치는 opus 고려.
- **흐름**: 스캔 → 심각도순 발견 목록 → 치명·중요 발견을 대응가가 패치 →
  **스캐너 재스캔으로 검증**. 패치는 고위험 산출물 — 단계 4 규칙대로 독립 리뷰어
  교차검증.
- **판정 기준**: 스캔이 4범주(인젝션·하드코드 비밀·의존성 CVE·설정 미스)를 커버했는가,
  패치가 재스캔을 통과했는가, 패치가 새 취약점·스코프 밖 변경을 만들지 않았는가.

## 서치팀 — 멀티모달 조달 (단독 + 타팀 지원)

- **발동 신호**: 조사·자료 조달이 작업의 핵심일 때. 타팀·타워커가 외부 자료를 필요로
  할 때(지원 파견).
- **편성**: 서처 1~N (웹/코드 모달별 병렬 — 멀티모달 스윕). 모델: sonnet, 잡일 haiku.
- **흐름**: 모달별 병렬 스윕 → 대장 종합. 지원 파견 시 결과 블록이 해당 서브작업의
  `{{컨텍스트}}` 보강분이 된다. 단계 1의 컨텍스트 팩 스카우트도 서처로 수행 가능.
- **판정 기준**: 조달물마다 출처(URL/file:line)가 있는가, 확신도 표기가 있는가,
  요청 범위를 커버하는가.
```

- [ ] **Step 2: 검증 — 팀 4종 + 필수 요소 존재 확인**

Run: `Grep pattern="^## " path="skills/run/teams.md" output_mode="content"`
Expected: 5줄 — 공통 원칙 + 테크팀·법무팀·보안팀·서치팀.

Run: `Grep pattern="발동 신호" path="skills/run/teams.md" output_mode="count"`
Expected: 4 (팀마다 1회).

Run: `Grep pattern="재스캔으로 검증|완료조건 해석의 보조|rabbits:팀/역할" path="skills/run/teams.md" output_mode="count"`
Expected: 3개 패턴 모두 1회 이상.

- [ ] **Step 3: 커밋**

```bash
git add skills/run/teams.md
git commit -m "$(cat <<'EOF'
feat: teams.md 신설 — 전문 팀 프리셋 4종 (테크·법무·보안·서치)

팀 = 편성 레시피(발동 신호·편성표·흐름·판정 기준). 인원은 기본값으로 대장이
조절(T6), 판정 기준은 단계 4 완료조건 해석의 보조(T7). 보안팀은
스캔→패치→재스캔 흐름 + 독립 리뷰어 교차검증, 서치팀은 타팀 지원 겸무(T4).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 3: SKILL.md 통합 — 단계 1 자동판단 + 단계 2 지연 로드 + 단계 3 팀 라벨

**Files:**
- Modify: `skills/run/SKILL.md` (단계 1: 48행 DAG 불릿 뒤 + 50~54행 로스터 표 / 단계 2: 64행 archetypes Read 불릿 뒤 / 단계 3: 84~88행 라벨 불릿)

**Interfaces:**
- Consumes: Task 2의 팀 명칭·발동 신호, Task 1의 아키타입 명칭.
- Produces: 대장 프로토콜의 팀 자동판단 규칙(단계 1 요약표) + teams.md 지연 로드 규칙 + 팀 라벨 형식.

- [ ] **Step 1: 단계 1(PLAN)에 팀 자동판단 요약표 추가**

기존(48행):
```
- 작업을 서브작업으로 분해하고 의존관계로 **미니 DAG**(병렬/순차)를 구성한다.
```
바로 아래에 삽입:
```
- **팀 자동판단**: 서브작업 성격이 아래 발동 신호에 걸리면 그 서브작업은 **팀 프리셋**으로
  편성 계획한다(편성·흐름 상세는 단계 2에서 `teams.md`를 읽어 적용):

  | 팀 | 발동 신호 (요약) |
  |----|-----------------|
  | 테크팀 | "기술적으로 가능한가" 판단, 기술 스택·아키텍처 결정, 신기술 도입 |
  | 법무팀 | 라이선스 검토, 상업적 사용 가능성, 의존성 도입, 배포·판매 전 점검 |
  | 보안팀 | 보안 점검, 인증·입력처리·비밀 취급 코드 작업, 배포 전 점검 |
  | 서치팀 | 조사·자료 조달이 핵심 작업일 때, 타팀·타워커가 외부 자료 필요할 때 |
```

- [ ] **Step 2: 로스터 표에 "팀" 컬럼 추가**

기존(52~53행):
```
  | 워커 | 아키타입 | 모델 | 완료조건 요약 | 의존 |
  |------|---------|------|--------------|------|
```
교체 후:
```
  | 워커 | 팀 | 아키타입 | 모델 | 완료조건 요약 | 의존 |
  |------|-----|---------|------|--------------|------|
```
표 바로 아래 불릿 추가:
```
  - "팀" 컬럼은 팀 프리셋 소속만 표기(무소속 워커는 공란).
```

- [ ] **Step 3: 단계 2(CAST)에 teams.md 지연 로드 추가**

기존(64행):
```
- 이 스킬의 베이스 디렉토리에 있는 `archetypes.md`를 Read로 읽는다(이 단계 첫 진입 시 1회).
```
바로 아래에 삽입:
```
- 단계 1에서 팀 매칭된 서브작업이 있으면 같은 디렉토리의 `teams.md`도 Read한다
  (이 단계 첫 진입 시 1회, 팀 없으면 안 읽음). 편성표대로 아키타입을 조합하고,
  팀 브리프(흐름·판정 기준 요약)를 해당 워커의 `{{제약}}`·`{{완료조건}}` 슬롯에 반영한다.
```

- [ ] **Step 4: 단계 3(DISPATCH) 라벨 규칙에 팀 형식 추가**

기존(84~88행):
```
- **워커 라벨(Agent `description`)은 직관적으로**: UI 하단에 그대로 표시되므로
  `rabbits:역할: 작업 요약` 형태로 짓는다(예: `rabbits:리서처: 문서 상호참조 조사`,
  `rabbits:구현가: 커밋 가이드 작성`). 앞의 `rabbits:` 네임스페이스로 이 워커가 rabbits가
  낳은 서브에이전트임을 드러내고, 역할·작업 요약은 단계 1 로스터의 워커명과 일치시켜
  사용자가 설명 없이도 누가 뭘 하는지 알게 한다.
```
교체 후:
```
- **워커 라벨(Agent `description`)은 직관적으로**: UI 하단에 그대로 표시되므로
  `rabbits:역할: 작업 요약` 형태로 짓는다(예: `rabbits:리서처: 문서 상호참조 조사`,
  `rabbits:구현가: 커밋 가이드 작성`). 팀 소속 워커는 `rabbits:팀/역할: 작업 요약`
  (예: `rabbits:보안팀/스캐너: 인증 모듈 취약점 스캔`). 앞의 `rabbits:` 네임스페이스로
  이 워커가 rabbits가 낳은 서브에이전트임을 드러내고, 역할·작업 요약은 단계 1 로스터의
  워커명과 일치시켜 사용자가 설명 없이도 누가 뭘 하는지 알게 한다.
```

- [ ] **Step 5: 검증 — 삽입 3지점 + 단계 4·루브릭 무변경 확인**

Run: `Grep pattern="팀 자동판단|teams.md.도 Read|rabbits:팀/역할" path="skills/run/SKILL.md" output_mode="content"`
Expected: 세 지점 모두 매치.

Run: `Grep pattern="teams" path="skills/run/review-rubric.md" output_mode="count"`
Expected: 0 (T7 — 루브릭 무변경).

Run: `git diff --stat HEAD -- skills/run/review-rubric.md`
Expected: 출력 없음(무변경).

- [ ] **Step 6: 커밋**

```bash
git add skills/run/SKILL.md
git commit -m "$(cat <<'EOF'
feat: SKILL.md에 팀 자동판단·지연 로드·팀 라벨 통합

단계 1에 팀 발동 신호 요약표(상주분은 이 표뿐 — 토큰 최소화) + 로스터 팀
컬럼, 단계 2에 teams.md 지연 로드(팀 매칭 시에만), 단계 3에 팀 라벨
rabbits:팀/역할 형식 추가. 단계 4·review-rubric.md는 무변경(T7).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 4: README.md — 팀 개념 반영

**Files:**
- Modify: `README.md` (동작 방식 표 33~34행, 파일 구조 블록 46~54행)

**Interfaces:**
- Consumes: Task 2의 팀 명칭 4종, Task 1의 아키타입 9종.

- [ ] **Step 1: 동작 방식 표의 단계 1·2 행 갱신**

기존(33~34행):
```
| 1 | 기획 | 서브작업 분해 → 미니 DAG + 완료조건, 팀 로스터, 컨텍스트 팩 1회 조립 |
| 2 | 편성 | 아키타입(리서처·구현가·리뷰어·테스터·기획가) + 모델·제한시간 배정 |
```
교체 후:
```
| 1 | 기획 | 서브작업 분해 → 미니 DAG + 완료조건, 전문 팀 자동판단, 로스터, 컨텍스트 팩 1회 조립 |
| 2 | 편성 | 아키타입 9종 + 전문 팀 프리셋 4종(테크·법무·보안·서치) + 모델·제한시간 배정 |
```

- [ ] **Step 2: 동작 방식 표 아래에 전문 팀 표 추가**

`완전 자율: 중간에 사용자에게 묻지 않는다(...)` 문단 **앞**에 삽입:
```
### 전문 팀 (프리셋)

| 팀 | 전문 분야 |
|----|----------|
| 테크팀 | 기술적 가능성 검토 (실현 가능성·리스크·대안) |
| 법무팀 | 라이선스·상업적 사용 검토 (법률 자문 아님) |
| 보안팀 | 취약점 점검 + 패치 + 재스캔 (방어 전용) |
| 서치팀 | 웹+코드 멀티모달 조달, 타팀 지원 |

대장이 작업 성격을 보고 자동 투입한다 — 별도 명령 없음.
```

- [ ] **Step 3: 파일 구조 블록에 teams.md 추가 + 아키타입 수 갱신**

기존(50~52행):
```
│   ├── SKILL.md          # 6단계 프로토콜
│   ├── archetypes.md     # 워커 역할 템플릿 5종
│   └── review-rubric.md  # 검토 루브릭 + 에스컬레이션 사다리
```
교체 후:
```
│   ├── SKILL.md          # 6단계 프로토콜
│   ├── archetypes.md     # 워커 역할 템플릿 9종
│   ├── teams.md          # 전문 팀 프리셋 4종 (테크·법무·보안·서치)
│   └── review-rubric.md  # 검토 루브릭 + 에스컬레이션 사다리
```

- [ ] **Step 4: 검증**

Run: `Grep pattern="전문 팀 프리셋 4종|아키타입 9종|teams.md" path="README.md" output_mode="count"`
Expected: 3개 패턴 모두 1회 이상.

- [ ] **Step 5: 커밋**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: README에 전문 팀 4종 반영

동작 방식 표(단계 1·2)에 팀 자동판단·프리셋을, 파일 구조에 teams.md를
반영하고 전문 팀 표를 추가.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 5: 0.2.0 릴리스 — version 상향 + validate + 전역 반영

**Files:**
- Modify: `.claude-plugin/plugin.json` (version 필드, 4행)

**Interfaces:**
- Consumes: Task 1~4 완료분 전체(릴리스 대상).

- [ ] **Step 1: version 0.1.0 → 0.2.0**

기존(4행):
```json
  "version": "0.1.0",
```
교체 후:
```json
  "version": "0.2.0",
```

- [ ] **Step 2: 매니페스트 검증**

Run: `claude plugin validate "E:\2026.Toy\Rabbits"`
Expected: 검증 통과(오류 0). SKILL.md 프론트매터 `name` 부재 경고는 기지(既知) 무해 — 실패 아님.

- [ ] **Step 3: 커밋**

```bash
git add .claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
chore: 버전 0.2.0 — 전문 팀 프리셋 4종 릴리스

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

- [ ] **Step 4: 전역 캐시 갱신**

전역 설치본은 캐시 스냅샷(`~/.claude/plugins/cache/rabbits/rabbits/0.1.0`)이므로 update 필수:

Run: `claude plugin update rabbits@rabbits`
Expected: 0.2.0으로 갱신 메시지. 실패 시 버전 상향 커밋이 반영됐는지(Step 3) 먼저 확인.

- [ ] **Step 5: 갱신 확인**

Run: `claude plugin list`
Expected: `rabbits` 0.2.0 표기.

---

## 자기검토 결과

**1. 스펙 커버리지 (§7 변경 매트릭스 대조):**
- archetypes.md 4종 추가(§4) → Task 1 (하드 제약 §4.2·경계 §4.3 포함 — 방어 전용·법률 고지·스파이크 최소·조달/조사 경계 전부 템플릿에 반영).
- teams.md 신설(§5) → Task 2 (공통 원칙 = T6 인원 기본값 + T7 판정 보조 + 대장 경유, 팀 4종 각각 발동 신호·편성·흐름·판정 기준).
- SKILL.md 단계 1·2·3(§6) → Task 3. 단계 4 무변경(T7) → Task 3 Step 5에서 무변경 검증.
- README(§7) → Task 4. plugin.json 0.2.0 + validate + 전역 update(§9) → Task 5.
- 실런 스모크(§9)는 배포 후 별도 관찰 항목 — 이 플랜의 태스크 아님(스펙도 "정성 관찰"로 규정).

**2. 플레이스홀더 스캔:** 모든 편집 스텝이 실제 삽입/교체 전문을 포함. TBD/TODO 없음.

**3. 타입(명칭) 정합성:** 아키타입 명칭(테크 검토가/라이선스 감사가/보안 감사가/서처)이 Task 1 정의 = Task 2 편성표 = Task 4 README에서 일치. 팀 명칭(테크팀/법무팀/보안팀/서치팀)과 발동 신호 문구가 Task 2(teams.md 상세) = Task 3(SKILL.md 요약표)에서 정합. 라벨 형식 `rabbits:팀/역할: 작업 요약`이 Task 2 공통 원칙 = Task 3 단계 3에서 동일.
