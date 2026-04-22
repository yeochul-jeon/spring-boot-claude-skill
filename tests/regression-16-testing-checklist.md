# Regression Test #16 — spring-testing 체크리스트 empirical 검증

날짜 초안: 2026-04-22

---

## 목적

`spring-testing` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro18/test-api
TEST=$SANDBOX/src/test/java
BUILD=$SANDBOX/build.gradle.kts
```

---

## §2 grep 자동 검증

```bash
# T1: H2 인메모리 설정 금지 (0건이어야 PASS)
echo "=== [T1] H2 설정 ===" && find $SANDBOX/src/test -name "*.yml" -o -name "*.properties" | xargs grep -l "h2\|H2" 2>/dev/null || echo "PASS"

# T2: @SpringBootTest 남용 확인 (0건이어야 PASS)
echo "=== [T2] @SpringBootTest ===" && grep -rn "@SpringBootTest" $TEST/ || echo "PASS"

# T3: @AutoConfigureTestDatabase(replace=NONE) 확인 (1건 이상이어야 PASS — @DataJpaTest 사용 시)
echo "=== [T3] @AutoConfigureTestDatabase(replace=NONE) ===" && grep -rn "AutoConfigureTestDatabase\|replace = NONE" $TEST/ || echo "FAIL: @AutoConfigureTestDatabase(replace=NONE) 없음"

# T4: @Testcontainers 사용 확인 (1건 이상이어야 PASS)
echo "=== [T4] @Testcontainers ===" && grep -rn "@Testcontainers\|MySQLContainer\|PostgreSQLContainer" $TEST/ || echo "FAIL: TestContainers 없음"

# T5: testcontainers 의존성 확인 (1건 이상이어야 PASS)
echo "=== [T5] testcontainers 의존성 ===" && grep -n "testcontainers" $BUILD || echo "FAIL: testcontainers 의존성 없음"

# T6: withReuse(true) 컨테이너 재사용 설정 (1건 이상이어야 PASS)
echo "=== [T6] withReuse ===" && grep -rn "withReuse" $TEST/ || echo "FAIL: withReuse(true) 없음"

# T7: Fixtures / ObjectMother 패턴 사용 (1건 이상이어야 PASS)
echo "=== [T7] Fixtures/ObjectMother ===" && grep -rn "Fixtures\|ObjectMother" $TEST/ || echo "FAIL: Fixtures 패턴 없음"

# T8a: @MockitoBean 사용 확인 (1건 이상이어야 PASS — @WebMvcTest 슬라이스 사용 시)
echo "=== [T8a] @MockitoBean ===" && grep -rn "@MockitoBean" $TEST/ || echo "FAIL: @MockitoBean 없음 — @MockBean 사용 중 가능성"

# T8b: @MockBean 잔존 확인 (0건이어야 PASS — Boot 3.4+ deprecated)
echo "=== [T8b] @MockBean 잔존 ===" && grep -rn "@MockBean" $TEST/ && echo "FAIL: @MockBean 발견 — @MockitoBean 으로 교체 필요" || echo "PASS"
```

---

## §3 수동 체크리스트

```
슬라이스 테스트
- [ ] @WebMvcTest 로 Controller 계층만 로드 (MVC 슬라이스)
- [ ] @DataJpaTest 로 Repository 계층만 로드 (JPA 슬라이스)
- [ ] @SpringBootTest 남용 없음 — E2E 범위만 사용

통합 테스트
- [ ] @DataJpaTest 사용 시 @AutoConfigureTestDatabase(replace = NONE) 적용
- [ ] 통합 테스트에 H2 없음 — TestContainers 로 실제 DB (MySQL/PostgreSQL) 사용
- [ ] @Testcontainers + @Container 정적 필드 선언
- [ ] @DynamicPropertySource 로 datasource url/username/password 주입
- [ ] withReuse(true) 컨테이너 재사용 설정

의존성
- [ ] testImplementation("org.testcontainers:junit-jupiter") 포함
- [ ] testImplementation("org.testcontainers:mysql") 또는 :postgresql 포함

픽스처
- [ ] 도메인별 Fixtures / ObjectMother 클래스 작성
- [ ] 인라인 new 도메인(...) 반복 없음
- [ ] UUID.randomUUID() · Faker 무분별한 랜덤 없음

MockitoBean
- [ ] @MockitoBean 사용 (@MockBean 없음 — Boot 3.4+ deprecated)

spring-principles 교차
- [ ] 테스트 클래스도 spring-principles 체크리스트 전 항목 통과
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-22 | 전체 (회원 CRUD Controller·Service·Repository + 통합 테스트) | FAIL (결함 4건) | 초기 baseline — retro #18 결함 수집 용도 |
| 2026-04-22 | 2차 회전 — SKILL 로드 상태 재실행 | PASS (결함 0건) | T1~T8 전부 기대값 충족; codex 리뷰 블로킹 없음 |
| 2026-04-22 | @MockitoBean 마이그레이션 (retro #19) | 문서 검증 PASS | SKILL.md·references·regression-16 @MockBean 0건; @MockitoBean ≥ 3건 |

### 2026-04-22 결함 목록

testing-domain 결함 (3건 — 탐지 공백):
- 결함 T1: `src/test/resources/application.yml` H2 인메모리 DB 설정 — TestContainers 미사용 → SKILL.md 항목 존재, grep 자동화 추가
- 결함 T3: `@DataJpaTest` 사용 시 `@AutoConfigureTestDatabase(replace = NONE)` 누락 → SKILL.md 항목 존재, grep 자동화 추가
- 결함 T4/T5: `testcontainers` 의존성 없음, `@Testcontainers` 없음 → SKILL.md 항목 존재, grep 자동화 추가

구조 공백 (1건):
- 결함 T_Fixture: 도메인별 Fixtures / ObjectMother 없음 — `@BeforeEach new Member()` 인라인 반복 → 신규 체크리스트 항목 추가

비결함 (PASS):
- T2: `@SpringBootTest` 남용 없음 ✅
- T10: `UUID.randomUUID()` 무분별 사용 없음 ✅
- T8: `@MockBean` — Boot 3.3.4 기준 정상 (Boot 3.4+는 `@MockitoBean` 권장 — follow-up)

> testing-domain 3건은 SKILL.md 항목 존재, grep 자동화 부재 → grep 섹션 추가로 탐지 수단 강화.
> T_Fixture는 구조 공백 — "도메인별 Fixtures / ObjectMother" 신규 체크리스트 항목 추가.

### 2026-04-22 2차 회전 — SKILL 로드 상태 결과

Sandbox: `/Users/cjenm/github/test-retro18-v2/test-api` (1차 `test-retro18/` 는 baseline 보존)

grep T1~T8 결과:

| 항목 | 기대값 | 결과 |
|------|--------|------|
| T1: H2 설정 (`src/test/resources`) | 0건 | PASS — `application.yml` 없음 |
| T2: `@SpringBootTest` 남용 | 0건 | PASS — 없음 |
| T3: `@AutoConfigureTestDatabase(replace=NONE)` | ≥ 1건 | PASS — `MemberRepositoryTest.java:20` |
| T4: `@Testcontainers` / `MySQLContainer` | ≥ 1건 | PASS — `MemberRepositoryTest.java:21,25` |
| T5: `testcontainers` 의존성 | ≥ 1건 | PASS — `build.gradle.kts:26,27` |
| T6: `withReuse(true)` | ≥ 1건 | PASS — `MemberRepositoryTest.java:29` |
| T7: `Fixtures`/`ObjectMother` | ≥ 1건 | PASS — `MemberFixtures` 전 테스트 파일 사용 |
| T8: `@MockBean` | 정보성 | Boot 3.3.4 기준 허용 — `MemberControllerTest.java:31` |

codex 리뷰: 블로킹 지적 없음 (committed SKILL.md 보강분 clean).

**2차 회전 판정: PASS — 결함 0건.** 1차(4건) → 2차(0건) 목표 달성.
