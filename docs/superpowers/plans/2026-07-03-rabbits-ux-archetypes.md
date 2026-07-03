# rabbits UX 계열 아키타입 3종 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 여정 점검가·UX 분석가·디자인 감사가 3종 추가(14→17종) + 0.4.0 릴리스(공개 리포 push 포함).

**Architecture:** 실행 코드 없음. archetypes.md 끝에 3종 추가(공통 규칙 상속, 경계 명문화는 템플릿 안 — 전례), teams.md·SKILL.md·review-rubric.md 무변경. **편집 → 검증(Grep/validate) → 커밋** 사이클.

**Tech Stack:** Markdown + plugin.json. 검증 Grep/validate. 한국어 Conventional Commits.

## Global Constraints

- 언어: 문서·주석·커밋 전부 한국어. 변수·식별자만 영어.
- 커밋 메시지 말미 트레일러 2줄:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3`
- 스펙 준수: `docs/superpowers/specs/2026-07-03-rabbits-ux-archetypes-design.md` 확정 결정 U1~U6.
- U1: 아키타입만 — teams.md·SKILL.md·review-rubric.md 변경 있으면 결함.
- **펜스 함정**: 신규 템플릿 펜스는 탑레벨(들여쓰기 0).
- 말미 고정 문구는 기존 14종과 글자 단위 동일:
  `잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 \`rabbits-result\` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.`
- 스코프 밖 파일 변경 금지. 실행 코드 생성 금지.

---

### Task 1: archetypes.md — UX 계열 3종 추가 (14종 → 17종)

**Files:**
- Modify: `skills/run/archetypes.md` (파일 끝, `## 14. 마이그레이터` 섹션 뒤)

**Interfaces:**
- Consumes: 공통 규칙 `rabbits-result` 블록, BLOCKED 프로토콜.
- Produces: 아키타입 명칭 3종 — **여정 점검가 (Journey Walker)** · **UX 분석가 (UX Analyst)** · **디자인 감사가 (Design Auditor)**. Task 2(README)가 수치 참조.

- [ ] **Step 1: 파일 끝 확인**

Read `skills/run/archetypes.md` — 마지막 섹션이 `## 14. 마이그레이터 (Migrator)`임을 확인. 신규 3종은 그 뒤에 이어 붙인다.

- [ ] **Step 2: 아키타입 15·16·17 추가**

파일 끝에 추가:

````
## 15. 여정 점검가 (Journey Walker)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet

```
너는 여정 점검가다. 사용자 시나리오를 처음부터 끝까지 실제로 주행한다(작업이 지정한
수단 — 브라우저·CLI 등) — 어떤 파일도 수정 금지. 막힘 = 진행 불가·오류뿐 아니라
"다음에 뭘 해야 할지 모르겠는 지점"도 포함한다. 주행 수단이 없으면 추정으로 강등하지
말고 BLOCKED로 반환하라. 주행하지 않은 단계를 통과로 보고하지 않는다.
(경계: 검증가는 기능이 동작하는지 기술 관찰하고, 여정 점검가는 사용자가 여정을
통과하는지 본다 — 동작해도 사용자가 못 찾으면 막힘이다.)

컨텍스트: {{컨텍스트}}
작업: {{작업}} (사용자 시나리오 + 주행 수단 명시)
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=시나리오별 주행
결과 + 막힘 지점 목록(위치·증상·심각도(치명/중요/사소)), evidence=단계별 실행 기록
(명령·스크린샷·출력 발췌), notes=주행 환경 1줄.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```

## 16. UX 분석가 (UX Analyst)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet

```
너는 UX 분석가다. 대상의 사용자 경험을 전문 기준으로 평가한다 — 흐름·레이블·
정보구조·일관성·접근성·휴리스틱. 어떤 파일도 수정 금지. 발견마다 위반한 원칙·기준을
인용하라 — "느낌상 불편"은 발견이 아니다. 심각도(치명/중요/사소) 분류 의무.
(경계: 여정 점검가는 특정 시나리오를 주행해 막힘을 찾고(동적), UX 분석가는 전문 기준
전반을 평가한다. 디자인 감사가는 원본과 같은지를 보고, UX 분석가는 경험이 좋은지를 본다.)

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=발견 목록
(위반 원칙 · 심각도 · 개선 제안 1줄), evidence=발견별 화면/코드 근거, notes=총평 1줄.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```

## 17. 디자인 감사가 (Design Auditor)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet

```
너는 디자인 감사가다. 원본(A)과 구현(B)의 시각 정합을 엄격 대조한다 — 어떤 파일도
수정 금지. 동일 뷰포트·동일 조건에서 양쪽 스크린샷을 떠서 픽셀 단위로 대조한다.
뷰포트는 작업이 지정하고, 지정 없으면 1280×720. 불일치는 영역·좌표로 특정하라.
스크린샷 캡처가 불가한 환경이면 어림 대조로 강등하지 말고 BLOCKED로 반환하라.
판정만 한다 — 수정 제안은 영역별 1줄로 제한.
(경계: UX 분석가는 경험이 좋은지를 보고, 디자인 감사가는 원본과 같은지를 본다.)

컨텍스트: {{컨텍스트}}
작업: {{작업}} (원본 A·구현 B 접근 방법 명시)
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=영역별 정합 판정
(일치/불일치 목록), evidence=스크린샷 쌍 위치 + 불일치 영역 좌표·설명, notes=캡처
환경 조건(뷰포트·배율) 1줄.
{{출력형식}}
잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 공통 규칙의 `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 그 블록을 붙여라. 너의 결과 블록이 곧 산출물이다.
```
````

- [ ] **Step 3: 검증 — 17종 + 말미 문구 + 규율 문구**

Run: `Grep pattern="^## [0-9]" path="skills/run/archetypes.md" output_mode="content"`
Expected: 17줄 (1.리서처 ~ 17.디자인 감사가).

Run: `Grep pattern="너의 결과 블록이 곧 산출물이다" path="skills/run/archetypes.md" output_mode="count"`
Expected: 공통 규칙 1회 + 템플릿 17회 = 18.

Run: `Grep pattern="주행 수단이 없으면|픽셀 단위로 대조|위반한 원칙|1280×720" path="skills/run/archetypes.md" output_mode="count"`
Expected: 4개 패턴 전부 1회 이상.

teams.md·SKILL.md·review-rubric.md 무변경 확인:
Run: `git diff --stat HEAD -- skills/run/teams.md skills/run/SKILL.md skills/run/review-rubric.md`
Expected: 출력 없음.

- [ ] **Step 4: 커밋**

```bash
git add skills/run/archetypes.md
git commit -m "$(cat <<'EOF'
feat: UX 계열 아키타입 3종 추가 — 여정 점검가·UX 분석가·디자인 감사가

14→17종. 전부 판정·보고형(파일 수정 금지). 여정 점검가·디자인 감사가는
수단 부재 시 BLOCKED(어림 강등 금지, U3), 디자인 감사가는 픽셀 단위
대조(기본 뷰포트 1280×720, U2), UX 분석가는 기준 인용 의무(U4).
경계 명문화 3건은 템플릿 안(U5).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 2: README.md — 17종 반영 (2곳)

**Files:**
- Modify: `README.md` (동작 방식 표 단계 2 행 34행 부근, 파일 구조 63행 부근)

**Interfaces:**
- Consumes: Task 1의 수치(17종).

- [ ] **Step 1: 동작 방식 표 단계 2 행 갱신**

기존(34행):
```
| 2 | 편성 | 아키타입 14종 + 전문 팀 프리셋 5종(테크·법무·보안·서치·QA) + 모델·제한시간 배정 |
```
교체 후:
```
| 2 | 편성 | 아키타입 17종 + 전문 팀 프리셋 5종(테크·법무·보안·서치·QA) + 모델·제한시간 배정 |
```

- [ ] **Step 2: 파일 구조 주석 갱신**

기존(63행 부근):
```
│   ├── archetypes.md     # 워커 역할 템플릿 14종
```
교체 후:
```
│   ├── archetypes.md     # 워커 역할 템플릿 17종
```

- [ ] **Step 3: 검증**

Run: `Grep pattern="아키타입 17종|템플릿 17종" path="README.md" output_mode="count"`
Expected: 2개 패턴 각 1회.

Run: `Grep pattern="14종" path="README.md" output_mode="count"`
Expected: 0 (옛 수치 잔존 없음).

- [ ] **Step 4: 커밋**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: README 아키타입 17종 반영

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

---

### Task 3: 0.4.0 릴리스 — version + validate + push + 전역 반영

**Files:**
- Modify: `.claude-plugin/plugin.json` (version 필드, 4행)

**Interfaces:**
- Consumes: Task 1~2 완료분.

- [ ] **Step 1: version 0.3.0 → 0.4.0**

기존(4행):
```json
  "version": "0.3.0",
```
교체 후:
```json
  "version": "0.4.0",
```

- [ ] **Step 2: 매니페스트 검증**

Run: `claude plugin validate "E:\2026.Toy\Rabbits"`
Expected: 통과(오류 0). SKILL.md `name` 경고는 기지 무해.

- [ ] **Step 3: 커밋**

```bash
git add .claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
chore: 버전 0.4.0 — UX 계열 아키타입 3종 릴리스

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tsdu2aet2m4EF2z3jxqxs3
EOF
)"
```

- [ ] **Step 4: 원격 push (공개 리포 반영)**

Run: `git push origin main`
Expected: main → origin/main 갱신. 공개 사용자는 이 시점부터 0.4.0 접근 가능.

- [ ] **Step 5: 전역 캐시 갱신 + 확인**

Run: `claude plugin update rabbits@rabbits`
Expected: 0.4.0 갱신 메시지.

Run: `claude plugin list`
Expected: `rabbits` 0.4.0 표기.

---

## 자기검토 결과

**1. 스펙 커버리지 (§5 매트릭스 대조):** archetypes 3종 + 하드 제약(§4.2) + 경계 3건(§4.3) → Task 1 (U2 픽셀·1280×720, U3 BLOCKED, U4 기준 인용 전부 템플릿에 반영) / README 2곳 → Task 2 / 0.4.0 + validate + push + 전역(§7, U6) → Task 3. teams·SKILL·rubric 무변경(U1) → Task 1 Step 3에서 확인. 실런 스모크(§7)는 배포 후 정성 관찰(전례).

**2. 플레이스홀더 스캔:** 전 스텝 삽입/교체 전문 포함. TBD 없음.

**3. 명칭 정합성:** 3종 명칭이 Task 1 정의 = Task 2 수치 참조에서 일치. 경계 문구의 상호 참조(검증가·여정 점검가·UX 분석가·디자인 감사가)가 템플릿 간 대칭. 검증 수치 재계산: 섹션 17, 말미 문구 18(공통 1+템플릿 17), README "14종" 잔존 0.
