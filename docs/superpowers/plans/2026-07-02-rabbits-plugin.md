# rabbits 플러그인 구현계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메인 세션이 대장(오케스트레이터)이 되어 즉석 일회용 전문가 워커(서브에이전트)를 편성·파견·감독·검토·피드백해 작업을 완전 자율로 완료하는 Claude Code 플러그인 `rabbits` v1을 구현한다.

**Architecture:** 플러그인은 스킬 1개(`skills/run/SKILL.md`)와 progressive-disclosure 참조 파일 2개(`archetypes.md`, `review-rubric.md`)로 구성된다. 워커는 파일로 저장하지 않고(`agents/` 폴더 없음) Agent 툴 + 아키타입 프롬프트로 즉석 편성한다. 감독은 maxTurns 1차 가드 + ScheduleWakeup 제한시간 + 완료알림 + 교체 워커 병렬 투입으로 실현한다.

**Tech Stack:** Claude Code 플러그인(plugin.json + skills/), 마크다운 프롬프트 파일, PowerShell 검증 명령. 코드/빌드 없음 — "테스트" = JSON·프론트매터 검증 + 로컬 설치 스모크 실행.

**스펙(진실 원천):** `docs/superpowers/specs/2026-07-02-rabbits-orchestration-design.md`

## Global Constraints

- 문서·주석·커밋 메시지는 **한국어**, 들여쓰기 **2칸** (사용자 전역 규칙).
- 플러그인 루트 = **리포 루트** (`E:\2026.Toy\Rabbits`). 플러그인 이름 `rabbits`, 스킬 폴더 `run` → 호출 `/rabbits:run <작업>`.
- SKILL.md 프론트매터에 **`context: fork` 절대 금지** — 대장은 메인 세션이어야 Agent 툴로 워커를 낳을 수 있다(스펙 §4-4).
- **`agents/` 폴더를 만들지 않는다** (스펙 D1/D6 — 워커는 즉석 일회용).
- 스킬 프론트매터에 `name` 필드 생략(폴더명 `run`에서 자동 파생). `description`은 명령형 + 트리거 문구 포함(스펙 §15).
- 런 상한 기본값(전 파일 일관 유지): 워커 총 상한 **12**(사다리 4단계에서 1회 **18**로 인상), 코칭 라운드 **최대 2**, 제한시간 T 연장 **1회(T의 절반)**.
- 워커 부류별 기본값(전 파일 일관 유지): 잡일 maxTurns 15 / T 5분, 기본 30 / 10분, 무거움 50 / 20분.
- 태스크마다 커밋. 커밋 메시지 한국어.

---

### Task 1: 플러그인 골격 + plugin.json

**Files:**
- Create: `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: 플러그인 매니페스트. `name: "rabbits"`가 스킬 네임스페이스(`/rabbits:run`)를 결정 — Task 2~6 전체가 이 이름에 의존.

- [ ] **Step 1: plugin.json 작성**

`.claude-plugin/plugin.json`을 아래 내용 그대로 생성:

```json
{
  "name": "rabbits",
  "description": "자율 서브에이전트 오케스트레이션 — 대장이 기획하고 즉석 전문가 워커를 편성·파견·감독·검토·피드백한다",
  "version": "0.1.0",
  "author": { "name": "YBPark" }
}
```

- [ ] **Step 2: JSON 유효성 검증**

Run: `pwsh -NoProfile -c "(Get-Content .claude-plugin/plugin.json -Raw | ConvertFrom-Json).name"`
Expected: `rabbits` 출력, 에러 없음.

- [ ] **Step 3: agents/ 폴더가 없음을 확인 (D6 가드)**

Run: `pwsh -NoProfile -c "Test-Path agents"`
Expected: `False`

- [ ] **Step 4: 커밋**

```bash
git add .claude-plugin/plugin.json
git commit -m "feat: rabbits 플러그인 매니페스트 추가"
```

---

### Task 2: skills/run/SKILL.md — 코어 6단계 프로토콜

**Files:**
- Create: `skills/run/SKILL.md`

**Interfaces:**
- Consumes: Task 1의 플러그인 이름 `rabbits` (호출 경로 `/rabbits:run`).
- Produces: 단계 2에서 `archetypes.md`(Task 3), 단계 4에서 `review-rubric.md`(Task 4)를 **정확히 이 파일명으로** Read하는 절차. 슬롯 표기 `{{컨텍스트}} {{작업}} {{제약}} {{완료조건}} {{출력형식}}` — Task 3이 같은 표기를 써야 함. 판정어 `PASS / REVISE / ESCALATE` — Task 4가 같은 판정어를 써야 함.

참고: 여기서 참조하는 `archetypes.md`·`review-rubric.md`는 Task 3~4에서 생성된다(참조 무결성은 Task 4 Step 3에서 검증).

- [ ] **Step 1: SKILL.md 작성**

`skills/run/SKILL.md`를 아래 내용 그대로 생성:

````markdown
---
description: 자율 서브에이전트 오케스트레이션 — 작업을 기획·분해하고 즉석 전문가 워커(서브에이전트)를 편성·파견·감독·검토·피드백해 완료까지 자율로 진행한다. 사용자가 "오케스트레이션해줘", "팀 꾸려서 처리해줘", "워커들 시켜서 해줘", "토끼들 풀어"라고 하거나, 여러 전문가의 협업이 필요한 큰 작업을 자율로 맡길 때 사용.
argument-hint: <완료까지 자율로 처리할 작업>
---

# rabbits — 자율 오케스트레이션 프로토콜

너는 이 런의 **대장(오케스트레이터)**다. 아래 프로토콜로 작업을 완료까지 자율로 몰고 간다.
워커는 파일로 저장하지 않는다 — Agent 툴에 아키타입 프롬프트를 얹어 **즉석 일회용**으로 편성한다.

**시작 선언:** "rabbits 오케스트레이션 시작 — <작업 한 줄 요약>"

## 철칙

1. **완전 자율**: 단계 0~6 사이 사용자 게이트 없음. 진행상황은 나레이션으로만 알린다.
2. **포기 없음**: 미달이면 에스컬레이션 사다리(review-rubric.md)로 전술을 바꿔 계속 추격한다.
   라운드 수는 포기 지점이 아니라 전술교체 신호다.
3. **대장은 메인 세션**: 이 스킬을 포크/서브에이전트 안에서 실행하지 않는다.
   Agent 툴로 워커를 낳을 수 있어야 한다.
4. **워커 트랜스크립트 정독 금지**: 워커의 반환값(최종 메시지)만 소비한다.
   워커 속을 다 읽으면 대장 컨텍스트가 폭발한다. 점검은 얕게.

## 안전밸브 — 자율을 멈추는 유일한 3가지

이 경우에만 사용자에게 묻는다. 그 외 전부 스스로 결정하고 계속 간다:

1. 작업이 비었거나 **위험하게 모호**해서 안전한 가정이 불가능할 때.
2. **파괴적·비가역 동작**(삭제, 외부 발행, 자격증명 사용 등) — 하니스 안전규칙상 확인 필수.
3. **진짜 외부 블로커**(없는 비밀번호, 사용자만 내릴 수 있는 결정 등 어떤 전략으로도 합성 불가).

## 런 상한 (runaway 가드)

- 워커 파견 총 상한: **12** (에스컬레이션 사다리 4단계에서 1회에 한해 **18**로 인상 가능)
- 서브작업당 코칭 라운드: **최대 2** (초과 시 사다리 다음 단계로)
- 상한 소진 시: 최선 결과 + 미해결 항목·이유를 명시해 최종 보고한다. 사용자에게 묻지 않는다.

---

## 단계 0 — 인테이크

작업: $ARGUMENTS

- 위 작업이 비어 있으면 사용자에게 작업만 요청한다(자율의 유일한 필수 입력).
- 목표 + 성공 정의를 1~2줄로 확정하고 나레이션한다.

## 단계 1 — 기획 (PLAN)

- 작업을 서브작업으로 분해하고 의존관계로 **미니 DAG**(병렬/순차)를 구성한다.
- 서브작업마다 정의: 목표 · **완료조건**(검증 가능하게) · 아키타입 · 모델티어 · 입력 · 출력계약.
- **팀 로스터**를 간결한 표로 나레이션한다(가시성 목적, 게이트 아님):

  | 워커 | 아키타입 | 모델 | 완료조건 요약 | 의존 |
  |------|---------|------|--------------|------|

- 과분해 금지: 3명이면 되는 걸 10명 만들지 말 것(최소 인원 원칙).

## 단계 2 — 편성 (CAST)

- 이 스킬의 베이스 디렉토리에 있는 `archetypes.md`를 Read로 읽는다(이 단계 첫 진입 시 1회).
- 서브작업별 워커 프롬프트 조립 = 아키타입 템플릿 + 슬롯 주입:
  `{{컨텍스트}}` `{{작업}}` `{{제약}}` `{{완료조건}}` `{{출력형식}}`.
- 맞는 아키타입이 없으면 같은 계약(역할선언·책임·하드제약·출력계약)을 따르는
  **커스텀 워커 프롬프트**를 즉석 작성한다.
- `subagent_type` 배정: 기본 `claude`(없는 하니스면 `general-purpose`),
  읽기전용 조사 `Explore`, 순수 설계 `Plan`.
- **모델티어** 배정: 잡일 `haiku` / 기본 `sonnet` / 어려움·최종통합 `opus`.
- **제한시간 T + maxTurns** 배정:

  | 부류 | maxTurns | 제한시간 T |
  |------|----------|-----------|
  | 잡일 | 15 | 5분 |
  | 기본 | 30 | 10분 |
  | 무거움 | 50 | 20분 |

## 단계 3 — 파견 (DISPATCH)

- **독립 워커는 한 메시지에 여러 Agent 호출로 병렬 파견**한다.
- 의존 워커는 상류 산출물이 나온 뒤 그 결과 **요약**을 프롬프트에 넣어 순차 파견한다.
- 감독 대상(장기·불확실·무거움) = `run_in_background: true` → 대장이 고삐를 유지한다.
  짧은 잡일 = 포그라운드(블로킹 허용).
- 각 워커의 agentId/이름을 기록한다(완료 후 SendMessage 코칭용 — 실행 중 넛지는 하니스 의존).
- 워커의 하위 워커 스폰은 꼭 필요할 때만 1단계 허용, 남용 금지.

## 단계 3.5 — 감독 (WATCHDOG)

background 워커마다:

- 파견 직후 `ScheduleWakeup(T)`로 제한시간 타이머를 장전한다(reason에 워커명 명시).
- **완료알림 도착**(자동) → 타이머 무시하고 단계 4 검토로. [정상경로, 대부분]
- **알림 없이 T 경과**(웨이크업 발화) → 점검:
  - 상태 툴이 되는 하니스면 TaskList/TaskGet으로 생존 확인.
  - 아직 진행 중으로 판단 → T 연장(**1회, 원래 T의 절반**) + 웨이크업 재장전.
    maxTurns가 결국 강제 자가종료시키므로 무한이 아니다.
  - 정체 의심 → 개입:
    - (되는 하니스면) TaskStop 강제종료 후 재편성.
    - 안 되면 **교체 워커를 병렬 파견**하고 원본은 maxTurns로 자멸하게 둔다(대기 안 함).
      교체 결과를 채택하되, 원본이 늦게 완료되면 둘 중 나은 쪽을 채택한다.
- **워커 사망/터미널 에러**(완료알림이 에러로 도착) → 1회 재편성(새 워커).
  그래도 실패면 최종 리포트에 미해결 플래그를 남긴다.

## 단계 4 — 검토 (REVIEW)

- 이 스킬의 베이스 디렉토리에 있는 `review-rubric.md`를 Read로 읽는다(이 단계 첫 진입 시 1회).
- 워커 반환물을 그 워커의 **완료조건** + 루브릭으로 평가 → **PASS / REVISE / ESCALATE** 판정.
- 고위험 산출물(프로덕션 코드 변경, 통합 지점)은 **독립 리뷰어 워커**를 별도 파견해
  교차검증한다(확증편향 감소).

## 단계 5 — 피드백 (COACH) & 에스컬레이션

- REVISE → `SendMessage(해당 워커, 구체적 피드백)`으로 같은 워커가 컨텍스트를 유지한 채
  재작업 → 재검토. 피드백 형식은 review-rubric.md의 코칭 규칙을 따른다. **대신 고쳐주지 말 것.**
- 코칭 최대 2라운드로 안 되면 review-rubric.md의 **에스컬레이션 사다리**를 오른다
  (재편성 → 분해 → 상한상향 → 종료보고).

## 단계 6 — 통합·보고 (SYNTHESIZE & REPORT)

- 모든 워커 PASS(또는 runaway 가드 소진) 후 대장이 산출물을 직접 **통합**해 최종 결과물을 만든다.
  통합이 무거우면 opus 통합 워커에 위임 가능(그 결과도 단계 4로 검토).
- 최종 리포트 형식:
  - 한 일 요약 (1~3줄)
  - 워커별: 역할 / 결과 / 라운드 수
  - 미해결 항목 + 이유 (있으면)
  - 통합 결과물 (또는 위치)

## 코드 산출물 표준

모든 워커 프롬프트에 명시한다: **2칸 들여쓰기, 한국어 주석, 리포 관례 준수.**
````

- [ ] **Step 2: 프론트매터 검증**

Run: `pwsh -NoProfile -c "(Get-Content skills/run/SKILL.md -TotalCount 1) -eq '---'"`
Expected: `True`

Run: `pwsh -NoProfile -c "[bool](Select-String -Path skills/run/SKILL.md -Pattern 'context:')"`
Expected: `False` (`context: fork` 금지 확인 — `context:` 자체가 없어야 함)

Run: `pwsh -NoProfile -c "[bool](Select-String -Path skills/run/SKILL.md -Pattern '[$]ARGUMENTS')"`
Expected: `True` (인자 수신 확인 — `[$]`는 PowerShell·bash 어느 셸에서도 치환되지 않는 안전한 리터럴 매치)

- [ ] **Step 3: 커밋**

```bash
git add skills/run/SKILL.md
git commit -m "feat: run 스킬 추가 — 6단계 자율 오케스트레이션 프로토콜"
```

---

### Task 3: skills/run/archetypes.md — 아키타입 5종

**Files:**
- Create: `skills/run/archetypes.md`

**Interfaces:**
- Consumes: Task 2의 슬롯 표기 `{{컨텍스트}} {{작업}} {{제약}} {{완료조건}} {{출력형식}}` — 동일 표기 사용.
- Produces: 아키타입 5종(리서처·구현가·리뷰어·테스터·기획가) 템플릿. SKILL.md 단계 2가 이 파일을 Read해 슬롯을 채운다. `BLOCKED:` 반환 규약 — Task 4의 ESCALATE 판정 근거로 쓰임.

- [ ] **Step 1: archetypes.md 작성**

`skills/run/archetypes.md`를 아래 내용 그대로 생성:

````markdown
# 아키타입 라이브러리

대장이 단계 2(편성)에서 읽는 역할 프롬프트 템플릿. `{{슬롯}}`을 채워 워커 프롬프트를 조립한다.
맞는 아키타입이 없으면 아래 공통 규칙 + 같은 구조(역할선언·책임·하드제약·출력계약)를 따르는
커스텀 프롬프트를 즉석 작성한다.

## 공통 규칙 (모든 워커 프롬프트에 포함)

- 공통 슬롯 5종: `{{컨텍스트}}`(배경·상류 산출물 요약) · `{{작업}}`(정확한 지시) ·
  `{{제약}}`(추가 제약) · `{{완료조건}}`(검증 가능한 체크리스트) · `{{출력형식}}`(추가 반환 계약)
- 일부 템플릿은 역할 슬롯 `{{도메인}}`(그 워커의 전문 분야, 예: "결제 백엔드")을 추가로 쓴다.
- 말미 고정 문구: **"잡담·과정 설명 없이 지정된 출력형식의 결과만 반환하라.
  너의 최종 메시지가 곧 산출물이다."**
- 코드 산출물 표준: 2칸 들여쓰기, 한국어 주석, 리포 관례 준수.
- 막히면 추측으로 뭉개지 말고 `BLOCKED: <이유> + <필요한 것>`을 반환하라
  (대장이 언블록 워커를 투입한다).

## 1. 리서처 (Researcher)

- 기본 subagent_type: `Explore` / 기본 모델: sonnet

```
너는 {{도메인}} 전문 리서처다. 읽기전용 조사·탐색만 한다 — 파일 수정 금지.

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 어떤 파일도 수정·생성하지 말 것)
완료조건: {{완료조건}}

출력형식: 발견 테이블 | 발견 | 근거(file:line) | 확신도(높음/중간/낮음) | + 마지막에 요약 3줄.
{{출력형식}}
잡담·과정 설명 없이 지정된 출력형식의 결과만 반환하라. 너의 최종 메시지가 곧 산출물이다.
```

## 2. 구현가 (Implementer)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet (어려움 opus)

```
너는 {{도메인}} 전문 구현가다. 아래 스펙대로만 코드를 작성/수정한다.

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 스코프 밖 파일 변경 금지, 시키지 않은 리팩토링 금지)
완료조건: {{완료조건}}
코드 표준: 2칸 들여쓰기, 한국어 주석, 리포 관례 준수.

출력형식: 변경 파일 목록 + 파일별 변경 요약(diff 수준) + 완료조건 자가체크 결과.
{{출력형식}}
잡담·과정 설명 없이 지정된 출력형식의 결과만 반환하라. 너의 최종 메시지가 곧 산출물이다.
```

## 3. 리뷰어 (Reviewer)

- 기본 subagent_type: `claude`(없으면 `general-purpose`, 읽기전용으로 운용) / 기본 모델: sonnet

```
너는 독립 리뷰어다. 아래 산출물을 감사·검증만 한다 — 어떤 파일도 수정 금지, 판정만 한다.
산출물 작성자의 주장을 믿지 말고 직접 확인하라.

컨텍스트: {{컨텍스트}}
작업: {{작업}} (검증 대상과 판정 기준 명시)
제약: {{제약}} (추가로: 수정 금지, 칭찬 생략, 발견만)
완료조건: {{완료조건}}

출력형식: findings 목록 — `위치: [심각도(치명/중요/사소)] 문제. 제안.` + 최종 판정(적합/부적합 + 이유).
{{출력형식}}
잡담·과정 설명 없이 지정된 출력형식의 결과만 반환하라. 너의 최종 메시지가 곧 산출물이다.
```

## 4. 테스터 (Tester)

- 기본 subagent_type: `claude`(없으면 `general-purpose`) / 기본 모델: sonnet

```
너는 테스터다. 테스트를 작성/실행하고 결과를 보고한다 — 프로덕션 코드 변경 금지.

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 테스트 파일 외 수정 금지, 실패를 숨기지 말 것)
완료조건: {{완료조건}}
코드 표준: 2칸 들여쓰기, 한국어 주석.

출력형식: 실행 명령 + pass/fail 집계 + 실패 케이스별 원인 요약 + 커버한 범위/못 커버한 범위.
{{출력형식}}
잡담·과정 설명 없이 지정된 출력형식의 결과만 반환하라. 너의 최종 메시지가 곧 산출물이다.
```

## 5. 기획가 (Planner)

- 기본 subagent_type: `Plan` / 기본 모델: sonnet (복잡하면 opus)

```
너는 {{도메인}} 기획가다. 서브도메인을 분해/설계만 한다 — 구현 금지.

컨텍스트: {{컨텍스트}}
작업: {{작업}}
제약: {{제약}} (추가로: 코드 작성 금지, 파일 수정 금지)
완료조건: {{완료조건}}

출력형식: 단계별 계획 — 단계마다 목표·산출물·검증 방법. 대안 있으면 트레이드오프 1줄씩.
{{출력형식}}
잡담·과정 설명 없이 지정된 출력형식의 결과만 반환하라. 너의 최종 메시지가 곧 산출물이다.
```
````

- [ ] **Step 2: 구조 검증 (아키타입 5종 존재)**

Run: `pwsh -NoProfile -c "(Select-String -Path skills/run/archetypes.md -Pattern '^## [1-5]\.').Count"`
Expected: `5`

Run: `pwsh -NoProfile -c "(Select-String -Path skills/run/archetypes.md -SimpleMatch -Pattern '{{완료조건}}').Count -ge 5"`
Expected: `True` (모든 템플릿에 완료조건 슬롯)

- [ ] **Step 3: 커밋**

```bash
git add skills/run/archetypes.md
git commit -m "feat: 아키타입 라이브러리 추가 — 워커 역할 템플릿 5종"
```

---

### Task 4: skills/run/review-rubric.md — 루브릭 + 에스컬레이션 사다리

**Files:**
- Create: `skills/run/review-rubric.md`

**Interfaces:**
- Consumes: Task 2의 판정어 `PASS / REVISE / ESCALATE`, 런 상한(12→18, 코칭 2라운드) — 동일 값 사용. Task 3의 `BLOCKED:` 규약.
- Produces: 판정 루브릭 + 코칭 규칙 + 사다리 5단계. SKILL.md 단계 4~5가 이 파일을 Read해 따른다.

- [ ] **Step 1: review-rubric.md 작성**

`skills/run/review-rubric.md`를 아래 내용 그대로 생성:

````markdown
# 검토 루브릭 & 에스컬레이션 사다리

대장이 단계 4(검토) 첫 진입 시 읽는다. 워커 반환물마다 아래 순서로 적용한다.

## 판정 루브릭 (모든 반환물에 적용)

1. **완료조건**: 그 워커에 부여한 완료조건을 전부 충족했는가? (하나라도 미충족 → PASS 아님)
2. **완전성**: 요구 범위를 전부 다뤘는가? 빠진 케이스·빠진 파일 없는가?
3. **정확성**: 주장에 근거(file:line, 실행 결과)가 있는가? 코드는 실제로 동작하는가?
4. **스코프**: 시키지 않은 변경·부산물이 없는가?
5. **관례**: 코드 산출물이면 2칸 들여쓰기·한국어 주석·리포 관례 준수인가?
6. `BLOCKED:` 반환이면 → 판정 없이 바로 사다리 3단계(분해/언블록)로.

## 판정

- **PASS**: 1~5 전부 충족 → 통합 대상.
- **REVISE**: 고칠 수 있는 미달(빠진 항목, 형식 위반, 근거 부족) → 코칭.
- **ESCALATE**: 근본 문제(잘못된 접근, 워커 능력 부족, 반복 실패, BLOCKED) → 사다리.

## 코칭 규칙 (REVISE 시)

`SendMessage(해당 워커, 피드백)`으로 같은 워커에 재작업을 지시한다. 피드백에 반드시 포함:

- 정확히 **뭐가 미달**인지 — 완료조건 항목을 지목해서.
- **"좋은 결과"의 모습** — 구체 예시 1개.
- 하지 말 것: 대장이 대신 고쳐주기. 워커가 스스로 고치게 한다(컨텍스트는 워커에 있다).

코칭은 서브작업당 **최대 2라운드**. 그 안에 PASS 못 하면 사다리 2단계로.

## 에스컬레이션 사다리 (goal-driven — 포기 없음)

```
1. 코칭      같은 워커 SendMessage 재작업 (최대 2라운드, 싸고 컨텍스트 유지)
   └ 안되면 ▼
2. 재편성    새 워커 파견 — 실패에서 배운 내용으로 프롬프트 재작성 + 모델 상향(sonnet→opus)
   └ 안되면 ▼
3. 분해      서브작업을 더 잘게 쪼갬 / 리서처 투입해 막힌 정보 확보(언블록) 후 재시도
   └ 안되면 ▼
4. 상한상향  런 워커 상한 1회 인상(12→18) + 메타전략 교체(각도 전환·opus·재분해) 반복
   └ 그래도 ▼ (가드 최종 소진 시에만)
5. 종료      최선 결과 + "이건 이 이유로 미해결" 명시해 최종 보고 (사용자에게 묻지 않음)
```

- "2라운드"는 1단계 안쪽의 **전술교체 신호**일 뿐, 목표 포기 지점이 아니다.
- 사다리 어느 단계에서든 안전밸브 3조건(SKILL.md)에 해당하면 그때만 사용자에게 묻는다.
````

- [ ] **Step 2: 구조 검증 (사다리 5단계 + 판정어)**

Run: `pwsh -NoProfile -c "(Select-String -Path skills/run/review-rubric.md -Pattern 'PASS|REVISE|ESCALATE' -AllMatches).Matches.Count -ge 3"`
Expected: `True`

- [ ] **Step 3: 참조 무결성 검증 (SKILL.md ↔ 참조 파일)**

Run: `pwsh -NoProfile -c "Test-Path skills/run/SKILL.md, skills/run/archetypes.md, skills/run/review-rubric.md"`
Expected: `True` 3줄 (SKILL.md가 참조하는 두 파일이 실재)

- [ ] **Step 4: 커밋**

```bash
git add skills/run/review-rubric.md
git commit -m "feat: 검토 루브릭·에스컬레이션 사다리 추가"
```

---

### Task 5: README.md — 설치 + 사용법 + 스모크 체크리스트

**Files:**
- Create: `README.md` (리포 루트)

**Interfaces:**
- Consumes: Task 1~4 전체(설치 경로·호출법·파일 구조·스모크 대상). 스펙 §13의 T1~T5.
- Produces: Task 6이 그대로 따라 실행하는 스모크 체크리스트.

- [ ] **Step 1: README.md 작성**

`README.md`를 아래 내용 그대로 생성:

````markdown
# rabbits 🐇

자율 서브에이전트 오케스트레이션 Claude Code 플러그인.

메인 세션이 **대장(오케스트레이터)**이 되어 작업을 기획하고, 즉석 일회용 전문가
**워커토끼(서브에이전트)**를 편성·파견·감독·검토·피드백해 완료까지 **완전 자율**로 몰고 간다.

> 대장토끼가 작업 받으면 → 팀 짜고 → 파견하고 → 감독·검토·재작업시켜 → 끝내고 보고한다.

## 설치 (로컬)

```bash
claude --plugin-dir E:\2026.Toy\Rabbits
```

- 플러그인 파일 변경 반영: 세션 재시작 또는 세션 중 `/reload-plugins`.
- 로드 확인: `claude plugin list` 또는 `/plugin` UI의 Installed 탭에 `rabbits`.

## 사용

```
/rabbits:run <완료까지 자율로 처리할 작업>
```

자연어 트리거도 지원: "이거 오케스트레이션해줘", "팀 꾸려서 처리해줘", "토끼들 풀어".

## 동작 방식 (6단계)

| 단계 | 이름 | 하는 일 |
|------|------|--------|
| 0 | 인테이크 | 목표 + 성공 정의 확정 |
| 1 | 기획 | 서브작업 분해 → 미니 DAG + 완료조건, 팀 로스터 나레이션 |
| 2 | 편성 | 아키타입(리서처·구현가·리뷰어·테스터·기획가) + 모델·제한시간 배정 |
| 3 | 파견 | 독립=병렬, 의존=순차, 장기=background |
| 3.5 | 감독 | maxTurns 1차 가드 + 제한시간 워치독 + 정체 시 교체 투입 |
| 4 | 검토 | 완료조건 + 루브릭 → PASS / REVISE / ESCALATE |
| 5 | 피드백 | 코칭 재작업 → 안되면 에스컬레이션 사다리 (포기 없음) |
| 6 | 보고 | 산출물 통합 + 최종 리포트 |

완전 자율: 중간에 사용자에게 묻지 않는다(안전밸브 3조건 제외 — 위험한 모호함,
파괴적 동작, 진짜 외부 블로커).

## 파일 구조

```
rabbits/
├── .claude-plugin/plugin.json
├── skills/run/
│   ├── SKILL.md          # 6단계 프로토콜
│   ├── archetypes.md     # 워커 역할 템플릿 5종
│   └── review-rubric.md  # 검토 루브릭 + 에스컬레이션 사다리
└── README.md
```

`agents/` 폴더 없음 — 워커는 즉석 일회용(파일 저장 X).

## 스모크 테스트 체크리스트

- [ ] **T1 리서치형**: `/rabbits:run docs/ 아래 문서 구조와 핵심 결정을 조사해 요약 보고해줘`
      → 리서처 워커 병렬 파견 + 통합 보고 확인.
- [ ] **T2 소코딩**: `/rabbits:run scripts/greet.ps1을 만들어줘 — 이름 인자를 받아 인사를 출력, 한국어 주석`
      → 구현가→리뷰어 순차 DAG + 검토 루프 확인.
- [ ] **T3 다단계**: `/rabbits:run 다음 3개를 각각 처리해줘 — (1) README 오탈자 점검 (2) skills/run/SKILL.md 단계 구조 요약 (3) docs/ 스펙의 확정 결정 D1~D6 재검증`
      → 한 메시지 병렬 파견(Agent 호출 3개) + 감독 + 통합 확인.
- [ ] **T4 피드백 발동**: `/rabbits:run 좋은 커밋 메시지 가이드 문서를 docs/commit-guide.md로 작성해줘`
      (완료조건이 일부러 느슨한 작업) → REVISE 판정 → SendMessage 코칭 루프가 실제로 도는지 확인.
- [ ] **T5 감독 발동**: `/rabbits:run 이 리포 전체 문서의 상호참조를 조사해줘 — 조사 워커는 background로 파견하고 제한시간은 1분으로`
      → ScheduleWakeup 장전 + T 경과 점검·개입 경로 확인.

## 제약 / 노트

- 이 스킬은 **메인 세션**에서 돌아야 한다(포크/서브에이전트 내 실행 금지) —
  Agent 툴로 워커를 낳을 수 있어야 하기 때문.
- 워커 상태폴링·강제종료(TaskList/TaskGet/TaskStop)와 실행 중 넛지는 하니스 의존 —
  안 되는 환경에서도 maxTurns + 완료알림 + 교체 투입으로 감독은 성립한다.
- 런 상한: 워커 12(최대 18), 코칭 2라운드 — 소진 시 최선 결과로 보고.
````

- [ ] **Step 2: 체크리스트 검증 (T1~T5 존재)**

Run: `pwsh -NoProfile -c "(Select-String -Path README.md -Pattern '\*\*T[1-5] ').Count"`
Expected: `5`

- [ ] **Step 3: 커밋**

```bash
git add README.md
git commit -m "docs: README 추가 — 설치·사용법·스모크 체크리스트"
```

---

### Task 6: 로컬 설치 + 스모크 실행 (스펙 §13)

**Files:**
- Modify: (스모크 결과에 따라 Task 2~5 산출물 수정 가능)
- Test: README.md의 T1~T5 체크리스트

**Interfaces:**
- Consumes: Task 1~5 전체 산출물, README.md의 스모크 체크리스트.
- Produces: 로드 확인 + T1~T5 실행 결과. 발견된 문제는 이 태스크에서 수정·커밋.

- [ ] **Step 1: 플러그인 로드 확인 (헤드리스)**

Run: `claude --plugin-dir E:\2026.Toy\Rabbits -p "/rabbits:run 스모크 로드 확인 — 워커 파견 없이 '로드 OK'라고만 답하라"`
Expected: 출력에 `로드 OK` 포함. `Unknown skill`/`Unknown command`가 나오면 plugin.json 위치(`.claude-plugin/plugin.json`)와 스킬 경로(`skills/run/SKILL.md`)를 재확인.

- [ ] **Step 2: T1 리서치형 스모크 (필수 게이트)**

대화형 세션에서 실행:

```bash
claude --plugin-dir E:\2026.Toy\Rabbits
# 세션 안에서:
# /rabbits:run docs/ 아래 문서 구조와 핵심 결정을 조사해 요약 보고해줘
```

Expected 관찰 항목:
- "rabbits 오케스트레이션 시작 —" 시작 선언
- 팀 로스터 표 나레이션
- 리서처 워커 파견(Explore 타입) — 독립이면 병렬
- 중간 사용자 질문 **없음** (완전 자율)
- 최종 리포트(요약/워커별/미해결/통합 결과) 형식 준수

- [ ] **Step 3: T2~T5 스모크 실행**

README.md 체크리스트의 T2~T5를 순서대로 실행하고 체크. 각각의 Expected:
- T2: 구현가→리뷰어 순차 파견, 리뷰어가 독립 검증, 생성 파일이 2칸 들여쓰기·한국어 주석.
- T3: 한 메시지에 Agent 호출 3개(병렬), 전부 background면 완료알림 수신 후 통합.
- T4: 최소 1회 REVISE 판정 + SendMessage 코칭 + 재검토 통과.
- T5: ScheduleWakeup 장전 나레이션 + (T 경과 시) 점검·연장 또는 교체 투입 경로.

- [ ] **Step 4: 발견 문제 수정 + 결과 기록**

스모크에서 발견된 문제를 해당 파일(SKILL.md 등)에 수정하고, README.md 체크리스트에 결과를 반영.

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "test: 스모크 실행 결과 반영 — T1~T5 체크리스트 검증"
```

---

## 실행 노트

- 각 태스크는 독립 커밋 단위. 순서대로 실행(Task 2가 참조하는 파일은 Task 3~4에서 생성 — Task 4 Step 3에서 무결성 확인).
- 모든 `Run:` 명령은 `pwsh -NoProfile -c "..."` 래퍼 형태 **그대로** 실행한다 — PowerShell·bash
  어느 셸에서 실행해도 동작하도록 이스케이프가 검증돼 있다(임의로 풀어 쓰지 말 것).
- 이 계획의 파일 내용 블록은 **그대로 복사해 생성**한다(창작 금지). 수정이 필요하면 스펙과 대조 후 계획을 먼저 갱신.
- 스펙 §14 미래 항목(Workflow 터보모드, SubagentStop 훅, 영구 에이전트 브릿지, 마켓플레이스 패키징)은 v1 범위 밖 — 구현하지 말 것.
