# Regression Test #17 — 6개 스킬 전체 통합 리그레션 (retro #20)

날짜 초안: 2026-04-22

---

## 목적

6개 스킬(spring-init·principles·web·persistence·security·testing)의
개별 empirical 사이클이 완료된 시점에, 스킬 문서 전체를 대상으로
세 축의 정적(static) 회귀 검증을 수행한다.

1. **§A — 스킬 문서 자기참조 위반** (meta-regression):
   스킬이 강제하는 규칙을 스킬 예시 코드 자신이 위반하는지 확인.
2. **§B — Sandbox 기준 grep 재실행**:
   2차 회전(SKILL 로드 PASS) sandbox 에 대해 retro 당시 PASS 상태가 유지되는지 확인.
3. **§C — retro #19 마이그레이션 후처리**:
   `@MockBean` → `@MockitoBean` 마이그레이션 결과가 skills/ 전체에 반영됐는지 확인.

신규 코드 생성 없음. 기존 artifact 만으로 회귀 여부를 판단한다.

---

## §A 스킬 문서 자기참조 위반 체크

허용 예외 기준:
- "금지", "// 안티패턴", "Before" 블록 내 예시는 허용.
- grep 탐지 명령문 자체에 심볼이 등장하는 것은 허용.
- Spring Boot 이외 외부 라이브러리 버전 (`io.spring.dependency-management`, testcontainers 등)은 허용.
- 문서 작성 기준 표기 ("Boot X.Y.Z 기준으로 작성" 식의 메타 주석)는 허용.

```bash
SKILLS=/Users/cjenm/github/spring-boot-claude-skill/skills

# A1: spring-init — Boot 패치 버전 하드코딩 (코드 생성 맥락에서 0건이어야 PASS)
echo "=== [A1] spring-init 버전 하드코딩 ==="
grep -rn "[0-9]\+\.[0-9]\+\.[0-9]\+" $SKILLS/spring-init/ --include="*.md" --include="*.sh" \
  | grep -v "fallback\|안티패턴\|금지\|deprecated\|retro\|RELEASE.*→\|기준으로 작성\|dependency-management\|testcontainers\|mapstruct\|// " \
  || echo "PASS"

# A2: spring-principles — @Autowired 필드 주입 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A2] spring-principles @Autowired 필드 주입 ==="
grep -rn "@Autowired" $SKILLS/spring-principles/ --include="*.md" \
  | grep -v "금지\|안티패턴\|BAD\|Before\b\|// ×\|WRONG" \
  || echo "PASS"

# A3: spring-web — Controller 예시가 Entity 직접 반환 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A3] spring-web Controller Entity 반환 ==="
grep -rn "public Member\b\|public Order\b\|public Product\b\|public User\b" \
  $SKILLS/spring-web/ --include="*.md" \
  | grep -v "안티패턴\|금지\|BAD\|grep -rn" \
  || echo "PASS"

# A4: spring-persistence — @Transactional 이 Controller/Repository 예시에 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A4] spring-persistence @Transactional 경계 위반 예시 ==="
grep -rn "@Transactional" $SKILLS/spring-persistence/ --include="*.md" \
  | grep -v "Service\|transaction\.md\|readOnly\|rollbackFor\|propagation\|Propagation\|TestContainers\|grep -rn\|금지\|안티패턴" \
  || echo "PASS"

# A5: spring-security — 금지 심볼 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A5] spring-security deprecated 심볼 ==="
grep -rn "WebSecurityConfigurerAdapter\|NoOpPasswordEncoder" \
  $SKILLS/spring-security/ --include="*.md" \
  | grep -v "사용하지 않는다\|금지\|grep -rn\|안티패턴" \
  || echo "PASS"

# A6: spring-testing — @MockBean 잔존 (retro #19 이후 0건이어야 PASS)
echo "=== [A6] spring-testing @MockBean 잔존 ==="
grep -rn "@MockBean" $SKILLS/spring-testing/ --include="*.md" \
  | grep -v "retro\|→\|마이그레이션\|deprecated\|교체\|grep -rn" \
  || echo "PASS"
```

---

## §B Sandbox 기준 grep 재실행

각 retro 의 1차(baseline)·2차 회전 상태:

| retro | 1차 (맨세션) | 2차 회전 (SKILL 로드) |
|-------|-------------|----------------------|
| #14 spring-principles | test-retro14 BASELINE | 별도 sandbox 미생성 |
| #15 spring-web | test-retro15 BASELINE | 별도 sandbox 미생성 |
| #16 spring-persistence | test-retro16 BASELINE | 별도 sandbox 미생성 |
| #17 spring-security | test-retro17 BASELINE | 별도 sandbox 미생성 |
| #18 spring-testing | test-retro18 BASELINE | **test-retro18-v2 PASS** |

retro #14~#17 은 BASELINE 전용 sandbox (맨세션 결함 수집 용도) 로 2차 회전 sandbox 미생성.
retro #18 만 test-retro18-v2 에 2차 회전 PASS sandbox 가 존재 → 해당 sandbox 재검증.

### §B-1: test-retro18-v2 — regression-16 grep 재실행

```bash
SB=/Users/cjenm/github/test-retro18-v2/test-api
TEST=$SB/src/test/java
BUILD=$SB/build.gradle.kts

echo "=== [T1] H2 설정 (0건이어야 PASS) ==="
find $SB/src/test \( -name "*.yml" -o -name "*.properties" \) -print0 \
  | xargs -0 grep -l "h2\|H2" 2>/dev/null || echo "PASS"

echo "=== [T2] @SpringBootTest 남용 ==="
grep -rn "@SpringBootTest" $TEST/ || echo "PASS"

echo "=== [T3] @AutoConfigureTestDatabase(replace=NONE) ==="
grep -rn "AutoConfigureTestDatabase\|replace = NONE" $TEST/ || echo "FAIL"

echo "=== [T4] @Testcontainers / MySQLContainer ==="
grep -rn "@Testcontainers\|MySQLContainer\|PostgreSQLContainer" $TEST/ || echo "FAIL"

echo "=== [T5] testcontainers 의존성 ==="
grep -n "testcontainers" $BUILD || echo "FAIL"

echo "=== [T6] withReuse ==="
grep -rn "withReuse" $TEST/ || echo "FAIL"

echo "=== [T7] Fixtures/ObjectMother ==="
grep -rn "Fixtures\|ObjectMother" $TEST/ || echo "FAIL"

# T8a/T8b: test-retro18-v2 는 Boot 3.3.4 / retro #19 이전 생성 → @MockBean 잔존 예상
# (retro #18 2차 회전 당시 "Boot 3.3.4 기준 허용" 으로 기록)
echo "=== [T8a] @MockitoBean (retro #19 이전 sandbox — FAIL 예상) ==="
grep -rn "@MockitoBean" $TEST/ || echo "FAIL (expected — pre-retro19 sandbox)"

echo "=== [T8b] @MockBean 잔존 (retro #19 이전 sandbox — FAIL 예상) ==="
grep -rn "@MockBean" $TEST/ && echo "FAIL (expected — pre-retro19 sandbox)" || echo "PASS"
```

---

## §C retro #19 마이그레이션 후처리 검증

```bash
SKILLS=/Users/cjenm/github/spring-boot-claude-skill/skills
TESTS=/Users/cjenm/github/spring-boot-claude-skill/tests

# C1: @MockBean 0건 (설명·grep 맥락 제외)
echo "=== [C1] @MockBean in skills/spring-testing/ ==="
grep -rn "@MockBean" $SKILLS/spring-testing/ --include="*.md" \
  | grep -v "retro\|→\|마이그레이션\|deprecated\|교체\|grep -rn" \
  || echo "PASS (0건)"

# C2: @MockitoBean ≥ 3건
echo "=== [C2] @MockitoBean count ==="
COUNT=$(grep -rn "@MockitoBean" $SKILLS/spring-testing/ --include="*.md" | wc -l | tr -d ' ')
echo "@MockitoBean: $COUNT 건"
[ "$COUNT" -ge 3 ] && echo "PASS" || echo "FAIL"

# C3: regression-16 §2 에 T8a/T8b 존재
echo "=== [C3] regression-16 T8a/T8b ==="
grep -n "T8a\|T8b" $TESTS/regression-16-testing-checklist.md || echo "FAIL"
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-22 | §A meta-regression (6개 스킬 전체) | PASS | 자기참조 위반 0건 (허용 예외 맥락 제외) — 세부 §4a |
| 2026-04-22 | §B test-retro18-v2 T1~T7 | PASS | retro #18 2차 회전 상태 유지 — 세부 §4b |
| 2026-04-22 | §B test-retro18-v2 T8a/T8b | FAIL (예상) | retro #19 이전 sandbox (Boot 3.3.4) — 미교체 예상 결과 |
| 2026-04-22 | §C @MockitoBean 마이그레이션 | PASS | @MockBean 0건; @MockitoBean 11건 |

### §4a — §A meta-regression 세부

| 항목 | 결과 | 비고 |
|------|------|------|
| A1: spring-init 버전 하드코딩 | PASS | `4.0.5`는 "문서 작성 기준" 주석 (코드 생성 지시 아님); `1.1.7`은 외부 플러그인 버전 |
| A2: spring-principles @Autowired | PASS | `di.md:44,48` 및 `constructor-injection.md:9,12` 모두 `// 금지`·"Before" 안티패턴 맥락 |
| A3: spring-web Entity 반환 | PASS | SKILL.md:111 은 grep 탐지 명령문 자체 |
| A4: spring-persistence @Transactional 경계 위반 예시 | PASS | 모든 @Transactional 은 Service 예시 또는 rule 설명 |
| A5: spring-security deprecated 심볼 | PASS | "사용하지 않는다" 규칙 설명 및 grep 탐지 명령문 |
| A6: spring-testing @MockBean 잔존 | PASS | retro #19 이후 0건 유지 |

### §4b — §B test-retro18-v2 세부

| 항목 | 기대값 | 결과 |
|------|--------|------|
| T1: H2 설정 | 0건 | PASS — src/test 내 yml/properties 파일 없음 |
| T2: @SpringBootTest 남용 | 0건 | PASS |
| T3: @AutoConfigureTestDatabase(replace=NONE) | ≥ 1건 | PASS — MemberRepositoryTest.java:20 |
| T4: @Testcontainers / MySQLContainer | ≥ 1건 | PASS — MemberRepositoryTest.java:21,25 |
| T5: testcontainers 의존성 | ≥ 1건 | PASS — build.gradle.kts:26,27 |
| T6: withReuse(true) | ≥ 1건 | PASS — MemberRepositoryTest.java:29 |
| T7: Fixtures/ObjectMother | ≥ 1건 | PASS — MemberFixtures 전 테스트 파일 사용 |
| T8a: @MockitoBean | ≥ 1건 | FAIL (예상) — retro #19 이전 sandbox, Boot 3.3.4 기준 |
| T8b: @MockBean | 0건 | FAIL (예상) — retro #19 이전 sandbox, Boot 3.3.4 기준 |

> T8a/T8b FAIL 은 test-retro18-v2 가 retro #19(@MockitoBean 마이그레이션) 이전에 생성된
> Boot 3.3.4 증거물이므로 예상된 결과다. retro #18 결과표에 "Boot 3.3.4 기준 허용"
> 으로 이미 기록됨.

---

## 최종 판정

**§A·§B(예상 FAIL 제외)·§C 전부 PASS — 회귀 없음.**

개별 스킬 empirical 사이클 완료 후 통합 건강 진단 통과.
6개 스킬 전체가 자신이 강제하는 규칙을 예시 코드에서 위반하지 않으며,
retro #19 마이그레이션 결과도 유지된다.
