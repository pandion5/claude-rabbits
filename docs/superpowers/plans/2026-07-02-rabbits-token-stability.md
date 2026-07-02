# rabbits 토큰 효율·안정성 3개 개념 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** rabbits v1 프로토콜에 구조화 반환(`rabbits-result` 블록)·컨텍스트 팩·반환 예산 3개 개념을 문서로 추가해 토큰↓·안정성↑을 달성한다.

**Architecture:** 실행 코드 없음. `skills/run/archetypes.md`·`skills/run/SKILL.md`의 프로토콜 문구만 편집한다. 공통 규칙에 블록 포맷·예산·팩 규율을 1회 정의(DRY)하고, 각 아키타입과 SKILL 단계가 이를 참조한다. TDD 대신 **편집 → 검증(grep/read) → 커밋** 사이클을 쓴다.

**Tech Stack:** Markdown 문서. 검증은 Grep/Read. 커밋은 한국어 Conventional Commits(리포 관례, `docs/commit-guide.md` 준수 — 단 그 파일은 스모크 부산물이라 현재 트리에 없음, 관례만 따른다).

## Global Constraints

- 언어: 문서·주석·커밋 전부 한국어. 변수·식별자만 영어.
- 들여쓰기: 2칸.
- 커밋 메시지 말미: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- 스펙 준수: `docs/superpowers/specs/2026-07-02-rabbits-token-stability-design.md`의 확정 결정 E1~E5.
- E1: 구조화 반환 = 펜스드 `rabbits-result` 블록(툴 스키마 아님, 프롬프트 계약).
- E2: 워커는 PASS 자칭 금지 — `self_check`만 제출, 판정은 대장.
- E5: 블록 포맷·예산·팩 규율은 archetypes 공통 규칙에 1회 정의, 각 아키타입은 참조.
- 스코프 밖 파일 변경 금지. 실행 코드 생성 금지.

---

### Task 1: archetypes.md 공통 규칙 — 블록 포맷·반환 예산·팩 규율 추가

**Files:**
- Modify: `skills/run/archetypes.md` (공통 규칙 섹션, 현재 7~16행)

**Interfaces:**
- Produces: `rabbits-result` 블록 포맷 정의(다른 모든 태스크가 참조). 필드명 확정 — `outcome`(DONE|BLOCKED) · `deliverable` · `evidence` · `self_check` · `notes` · (BLOCKED 시) `blocker` · `need`.

- [ ] **Step 1: 공통 규칙 섹션을 연다**

Read `skills/run/archetypes.md` 7~16행(공통 규칙)을 확인한다. 기존 마지막 두 불릿이 대상:
- `- 말미 고정 문구: ...` (자연어 반환 지시)
- `- 막히면 추측으로 뭉개지 말고 \`BLOCKED: <이유> + <필요한 것>\`을 반환하라 ...`

- [ ] **Step 2: 말미 고정 문구 불릿을 블록 반환 지시로 교체**

기존:
```
- 말미 고정 문구: **"잡담·과정 설명 없이 지정된 출력형식의 결과만 반환하라.
  너의 최종 메시지가 곧 산출물이다."**
```
교체 후:
```
- 말미 고정 문구: **"잡담·과정 설명은 최종 메시지에 남겨도 되지만, 대장은 아래
  `rabbits-result` 블록만 읽는다. 반드시 최종 메시지 끝에 이 블록을 붙여라.
  너의 결과 블록이 곧 산출물이다."**
- **결과 블록 포맷** (모든 워커 공통):

      ```rabbits-result
      outcome: DONE            # DONE | BLOCKED
      deliverable: <결과물 또는 위치>
      evidence:
        - <판정에 필요한 최소 근거 file:line / 수치>
      self_check:
        - <완료조건1>: ✓
        - <완료조건2>: ✗ <이유>
      notes: <있으면 1줄>
      ```

  - `outcome`에 PASS/FAIL 같은 **최종 판정을 쓰지 말 것** — 판정은 대장 몫이다.
    워커는 `self_check`에 완료조건별 자가대조(✓/✗)만 적는다.
  - `evidence`는 판정에 필요한 **최소 근거만**. 전체 목록·원문 덤프 금지 —
    대장이 더 필요하면 SendMessage로 요청한다.
```

- [ ] **Step 3: BLOCKED 불릿을 블록의 BLOCKED 경로로 통합**

기존:
```
- 막히면 추측으로 뭉개지 말고 `BLOCKED: <이유> + <필요한 것>`을 반환하라
  (대장이 언블록 워커를 투입한다).
```
교체 후:
```
- 막히면 추측으로 뭉개지 말고 결과 블록에 `outcome: BLOCKED` + `blocker: <이유>` +
  `need: <필요한 것>`을 채워 반환하라(이때 `deliverable`·`self_check`는 생략).
  대장이 언블록 워커를 투입한다.
```

- [ ] **Step 4: 반환 예산 불릿을 코드 표준 불릿 뒤에 추가**

`- 코드 산출물 표준: 2칸 들여쓰기, 한국어 주석, 리포 관례 준수.` 불릿 **바로 아래**에 삽입:
```
- **반환 예산(소프트 상한, 목표치)**: 결과 블록은 잡일 ≤15줄 · 기본 ≤40줄 ·
  무거움 ≤80줄을 목표로 한다. 근거상 초과가 불가피하면 초과하되 이유를 `notes`에 1줄.
- **컨텍스트 팩 존중**: `{{컨텍스트}}`에 담겨 온 정보는 재조사하지 말 것.
  팩에 없고 네 작업에 필요한 것만 조사한다.
```

- [ ] **Step 5: 검증 — 블록·예산·팩 규율이 모두 있는지 확인**

Run: `Grep pattern="rabbits-result|반환 예산|컨텍스트 팩 존중|outcome: BLOCKED" path="skills/run/archetypes.md" output_mode="content"`
Expected: 4개 패턴 모두 매치. `rabbits-result`는 최소 1회(공통 규칙 정의부).

- [ ] **Step 6: 커밋**

```bash
git add skills/run/archetypes.md
git commit -m "$(cat <<'EOF'
feat: 아키타입 공통 규칙에 rabbits-result 블록·반환 예산 추가

워커가 최종 메시지 끝 고정 블록으로 판정+최소근거만 반환하도록 계약화.
기존 자연어 BLOCKED 규약을 블록의 outcome: BLOCKED 경로로 통합. 반환
예산(소프트 상한)과 컨텍스트 팩 재조사 금지 규율도 공통 규칙에 1회 정의.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: archetypes.md 아키타입 5종 — 출력형식을 블록 반환으로 통일

**Files:**
- Modify: `skills/run/archetypes.md` (리서처·구현가·리뷰어·테스터·기획가 5개 템플릿의 `출력형식:` 줄)

**Interfaces:**
- Consumes: Task 1이 정의한 `rabbits-result` 블록 필드(`deliverable`·`evidence`·`self_check`).
- Produces: 5개 아키타입이 역할별 산출을 블록 필드로 매핑하는 지시.

- [ ] **Step 1: 리서처 출력형식 교체**

기존:
```
출력형식: 발견 테이블 | 발견 | 근거(file:line) | 확신도(높음/중간/낮음) | + 마지막에 요약 3줄.
```
교체 후:
```
출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=발견 요약(핵심만),
evidence=발견별 근거 file:line + 확신도(높음/중간/낮음), notes=전체 요약 1줄.
```

- [ ] **Step 2: 구현가 출력형식 교체**

기존:
```
출력형식: 변경 파일 목록 + 파일별 변경 요약(diff 수준) + 완료조건 자가체크 결과.
```
교체 후:
```
출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=변경 파일 목록 +
파일별 변경 요약, self_check=완료조건별 자가대조, evidence=핵심 변경 지점 file:line.
```

- [ ] **Step 3: 리뷰어 출력형식 교체**

기존:
```
출력형식: findings 목록 — `위치: [심각도(치명/중요/사소)] 문제. 제안.` + 최종 판정(적합/부적합 + 이유).
```
교체 후:
```
출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. evidence=findings 목록
`위치: [심각도(치명/중요/사소)] 문제. 제안.`, self_check=검증 기준별 대조,
notes=적합성 소견 1줄(최종 판정은 대장 몫).
```

- [ ] **Step 4: 테스터 출력형식 교체**

기존:
```
출력형식: 실행 명령 + pass/fail 집계 + 실패 케이스별 원인 요약 + 커버한 범위/못 커버한 범위.
```
교체 후:
```
출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=실행 명령 +
pass/fail 집계, evidence=실패 케이스별 원인 요약, notes=커버한/못 커버한 범위 1줄.
```

- [ ] **Step 5: 기획가 출력형식 교체**

기존:
```
출력형식: 단계별 계획 — 단계마다 목표·산출물·검증 방법. 대안 있으면 트레이드오프 1줄씩.
```
교체 후:
```
출력형식: 결과는 공통 규칙의 `rabbits-result` 블록으로. deliverable=단계별 계획
(단계마다 목표·산출물·검증 방법), notes=대안별 트레이드오프 1줄씩(있으면).
```

- [ ] **Step 6: 검증 — 5종 모두 블록 참조로 바뀌었는지 확인**

Run: `Grep pattern="결과는 공통 규칙의 \`rabbits-result\` 블록으로" path="skills/run/archetypes.md" output_mode="count"`
Expected: count = 5.

추가 확인 — 옛 표현이 안 남았는지:
Run: `Grep pattern="출력형식: 발견 테이블|출력형식: 변경 파일 목록 \+|출력형식: findings 목록|출력형식: 실행 명령 \+|출력형식: 단계별 계획 —" path="skills/run/archetypes.md" output_mode="count"`
Expected: 매치 없음(0).

- [ ] **Step 7: 커밋**

```bash
git add skills/run/archetypes.md
git commit -m "$(cat <<'EOF'
feat: 아키타입 5종 출력형식을 rabbits-result 블록으로 통일

리서처·구현가·리뷰어·테스터·기획가의 자연어 출력형식을 공통 블록 필드
(deliverable/evidence/self_check/notes) 매핑으로 교체. 리뷰어는 최종 판정을
대장에 넘기도록 notes 소견만 남긴다(E2).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: SKILL.md 컨텍스트 팩 — 단계 1 조립 + 단계 2 주입

**Files:**
- Modify: `skills/run/SKILL.md` (단계 1 PLAN 끝 55행 부근, 단계 2 CAST 슬롯 설명 60~61행 부근)

**Interfaces:**
- Consumes: 없음(대장 프로토콜 문구).
- Produces: "컨텍스트 팩"이라는 명명된 산출물 — 단계 4/README가 참조 가능.

- [ ] **Step 1: 단계 1(PLAN)에 팩 조립 스텝 추가**

`- 과분해 금지: 3명이면 되는 걸 10명 만들지 말 것(최소 인원 원칙).` 불릿 **바로 아래**에 삽입:
```
- **컨텍스트 팩 조립**(로스터 나레이션 뒤 1회): 워커들이 공통으로 필요로 할 배경을
  대장이 한 번 모아 팩으로 만든다 — (a) 작업 배경 2~3줄 (b) 관련 파일 경로 + 각 한 줄
  요약 (c) 재조사 불필요한 확정 사실·제약. 말미에 **"이 팩 정보는 재조사 금지"**를 붙인다.
  - 기본은 대장 인라인 조립(저렴). 탐색량이 크거나 대장이 배경을 모르면 스카우트
    리서처 워커 1명을 먼저 파견하고 그 `rabbits-result` 블록을 팩으로 삼는다(하이브리드).
```

- [ ] **Step 2: 단계 2(CAST) 슬롯 주입에 팩 명시**

기존:
```
- 서브작업별 워커 프롬프트 조립 = 아키타입 템플릿 + 슬롯 주입:
  `{{컨텍스트}}` `{{작업}}` `{{제약}}` `{{완료조건}}` `{{출력형식}}`.
```
교체 후:
```
- 서브작업별 워커 프롬프트 조립 = 아키타입 템플릿 + 슬롯 주입:
  `{{컨텍스트}}` `{{작업}}` `{{제약}}` `{{완료조건}}` `{{출력형식}}`.
  - `{{컨텍스트}}`에는 단계 1에서 만든 **컨텍스트 팩** + 그 워커에만 해당하는
    상류 산출물 요약을 넣는다. 팩 공통부를 워커마다 다시 조사시키지 않는다.
```

- [ ] **Step 3: 검증 — 팩 조립·주입 문구 존재 확인**

Run: `Grep pattern="컨텍스트 팩 조립|컨텍스트 팩\*\* \+|재조사 금지|하이브리드" path="skills/run/SKILL.md" output_mode="content"`
Expected: 단계 1 조립 스텝과 단계 2 주입 문구가 모두 매치.

- [ ] **Step 4: 커밋**

```bash
git add skills/run/SKILL.md
git commit -m "$(cat <<'EOF'
feat: 컨텍스트 팩 추가 — 단계 1 조립·단계 2 주입

대장이 공통 배경을 1회 조립해 모든 워커의 {{컨텍스트}}에 주입, 워커 간
중복 재탐색을 제거. 기본은 인라인 조립, 탐색량 크면 스카우트 워커 1명이
팩을 만드는 하이브리드(E3).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: SKILL.md 단계 4 — 대장 판정을 self_check 블록 기반으로

**Files:**
- Modify: `skills/run/SKILL.md` (단계 4 REVIEW, 104~107행 부근)

**Interfaces:**
- Consumes: Task 1의 `rabbits-result` 블록(`self_check`·`evidence`·`outcome`).

- [ ] **Step 1: 단계 4 판정 불릿 확장**

기존:
```
- 워커 반환물을 그 워커의 **완료조건** + 루브릭으로 평가 → **PASS / REVISE / ESCALATE** 판정.
```
교체 후:
```
- 워커의 `rabbits-result` 블록을 소비한다 — `self_check`·`evidence`·`outcome`을
  그 워커의 **완료조건** + 루브릭으로 평가 → **PASS / REVISE / ESCALATE** 판정.
  워커의 `self_check`는 참고 자료일 뿐, PASS는 대장이 근거로 직접 확정한다(워커 자칭 불가).
- **결과 블록 누락·파손** 시 → 판정 없이 REVISE 1순위 사유("결과 블록 누락")로
  SendMessage 반려한다. `outcome: BLOCKED`이면 루브릭대로 사다리 3단계(언블록)로.
```

- [ ] **Step 2: 검증 — 블록 기반 판정·누락 반려 문구 존재 확인**

Run: `Grep pattern="rabbits-result. 블록을 소비|결과 블록 누락|self_check.는 참고" path="skills/run/SKILL.md" output_mode="content"`
Expected: 세 지점 모두 매치.

- [ ] **Step 3: 커밋**

```bash
git add skills/run/SKILL.md
git commit -m "$(cat <<'EOF'
feat: 단계 4 판정을 rabbits-result 블록 기반으로

대장이 워커 블록의 self_check/evidence/outcome으로 판정하되 PASS는 근거로
직접 확정(워커 자칭 불가, E2). 블록 누락·파손은 REVISE 1순위 사유로 반려.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: README.md — 동작 방식 표에 컨텍스트 팩 반영 (선택)

**Files:**
- Modify: `README.md` (동작 방식 6단계 표, 30~39행 부근)

**Interfaces:**
- Consumes: Task 3(컨텍스트 팩)·Task 1(결과 블록) 용어.

- [ ] **Step 1: 단계 1·3 행 문구에 팩·블록 반영**

기존 행:
```
| 1 | 기획 | 서브작업 분해 → 미니 DAG + 완료조건, 팀 로스터 나레이션 |
```
교체 후:
```
| 1 | 기획 | 서브작업 분해 → 미니 DAG + 완료조건, 팀 로스터, 컨텍스트 팩 1회 조립 |
```
기존 행:
```
| 4 | 검토 | 완료조건 + 루브릭 → PASS / REVISE / ESCALATE |
```
교체 후:
```
| 4 | 검토 | 워커 rabbits-result 블록(self_check) + 루브릭 → PASS / REVISE / ESCALATE |
```

- [ ] **Step 2: 검증 — README 반영 확인**

Run: `Grep pattern="컨텍스트 팩 1회 조립|rabbits-result 블록" path="README.md" output_mode="content"`
Expected: 두 행 모두 매치.

- [ ] **Step 3: 커밋**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: README 동작 방식 표에 컨텍스트 팩·결과 블록 반영

단계 1에 컨텍스트 팩 조립, 단계 4에 rabbits-result 블록 판정을 반영해
프로토콜 확장과 README를 정합시킴.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## 자기검토 결과

**1. 스펙 커버리지:**
- §4 결과 블록 포맷 → Task 1 Step 2. 대장 소비(§4.2) → Task 4.
- §5 컨텍스트 팩(조립·주체 E3) → Task 3.
- §6 반환 예산 → Task 1 Step 4.
- §7 변경 매트릭스: archetypes 공통 규칙 → Task 1 / 아키타입 5종 → Task 2 / SKILL 단계 1·2 → Task 3 / SKILL 단계 4 → Task 4 / README → Task 5. **전 항목 커버.**
- E1~E5 모두 Global Constraints + 해당 태스크에 반영.

**2. 플레이스홀더 스캔:** 모든 편집 스텝이 실제 삽입/교체 문구를 포함. TBD/TODO 없음.

**3. 타입 정합성:** 블록 필드명(`outcome`/`deliverable`/`evidence`/`self_check`/`notes`/`blocker`/`need`)이 Task 1 정의와 Task 2·4 참조에서 일치. 기존 자연어 `BLOCKED` 규약은 Task 1 Step 3에서 블록 경로로 통합(중복 제거).
