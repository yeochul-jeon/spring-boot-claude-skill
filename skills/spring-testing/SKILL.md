---
name: spring-testing
description: Use when writing tests for Spring Boot code. Trigger on
  "테스트 작성", "@WebMvcTest", "@DataJpaTest", "통합 테스트",
  "TestContainers". Enforces slice tests, TestContainers for integration,
  and builder-based fixtures over random data.
---

# Spring Testing

Spring Boot 테스트 계층의 표준 패턴.
슬라이스 테스트로 범위를 좁히고, 통합 테스트에는 TestContainers로 실제 엔진을 사용하며,
빌더/ObjectMother 픽스처로 테스트 의도를 드러낸다.

## 절대 원칙

1. **슬라이스 테스트 먼저.** `@SpringBootTest`는 슬라이스로 커버할 수 없는 E2E 흐름에만 사용한다.
2. **통합 테스트에서 H2·인메모리 DB 금지.** 운영 DB와 방언 차이로 버그를 은폐한다.
   `references/testcontainers.md` 패턴으로 실제 엔진을 사용한다.
3. **랜덤 값을 검증 의도 없이 쓰지 않는다.** 빌더 또는 ObjectMother로 테스트 의도를 명시한다.
4. **테스트 코드에도 `spring-principles` 체크리스트를 적용한다.** 생성자 주입,
   계층 책임 분리, DTO-Entity 분리는 테스트 헬퍼에도 동일하게 적용.

## 워크플로우

### 1. 테스트 범위 결정

| 목적 | 어노테이션 | 비고 |
|---|---|---|
| Controller 입출력 검증 | `@WebMvcTest` | MockMvc + `@MockBean`(Service) |
| Repository 쿼리 검증 | `@DataJpaTest` | TestContainers DB 사용 |
| JSON 직렬화 검증 | `@JsonTest` | JacksonTester |
| E2E 통합 플로우 | `@SpringBootTest` | 최소 범위로 제한 |

### 2. 의존성 확인

`build.gradle.kts`에 추가:

```kotlin
dependencies {
    testImplementation("org.springframework.boot:spring-boot-starter-test")  // JUnit 5 + AssertJ + Mockito 포함
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:mysql")          // MySQL 기본; PostgreSQL은 :postgresql
}
```

> `spring-boot-starter-test`와 `testcontainers` 버전은 Spring Boot BOM이 관리한다.
> `build.gradle.kts`에 버전 숫자를 직접 적지 않는다.

### 3. 슬라이스 테스트 작성

`references/slice-tests.md` 패턴 적용.

**Controller 슬라이스 예시**

```java
@WebMvcTest(MemberController.class)
class MemberControllerTest {

    @Autowired MockMvc mockMvc;
    @MockBean  MemberService memberService;

    @Test
    @WithMockUser
    void 회원_단건_조회_성공() throws Exception {
        given(memberService.findById(1L)).willReturn(MemberFixtures.aMember().build());

        mockMvc.perform(get("/api/v1/members/1"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.email").value("test@example.com"));
    }
}
```

Security 실제 로그인·세션·로그아웃 흐름 검증은 `references/slice-tests.md` 의 "Spring Security 통합 테스트" 섹션 참조.
(`formLogin()`, `MockHttpSession`, `@BeforeEach deleteAll()`, ProblemDetail jsonPath 패턴 포함)

### 4. 통합 테스트 (필요 시)

`references/testcontainers.md` 패턴 적용.

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)
@Testcontainers
class MemberRepositoryTest {

    @Container
    static MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0").withReuse(true);

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
    }
}
```

### 5. 픽스처 구성

`references/fixtures.md` 패턴 적용.

```java
// 도메인별 Builder — 테스트에서 변경할 필드만 덮어씀
Member member = MemberFixtures.aMember()
    .email("other@example.com")
    .build();

// ObjectMother — 시나리오 의미를 이름으로 드러냄
Member lockedMember = MemberFixtures.aLockedMember();
```

### 6. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] 슬라이스 어노테이션(`@WebMvcTest` / `@DataJpaTest` / `@JsonTest`)을 목적에 맞게 사용
- [ ] 통합 테스트에 H2 없음 — TestContainers로 실제 DB 엔진 사용
- [ ] `@AutoConfigureTestDatabase(replace = NONE)` 적용 (`@DataJpaTest` 사용 시)
- [ ] 픽스처에 `UUID.randomUUID()` · Faker 무분별한 랜덤 없음
- [ ] `@SpringBootTest`가 정말 필요한 E2E 범위로만 한정됨
- [ ] 컨테이너 재사용 설정(`withReuse(true)`) 적용 — 로컬 빌드 속도 보장
- [ ] `testImplementation("org.testcontainers:junit-jupiter")` 의존성 포함
- [ ] 테스트 코드도 `spring-principles` 체크리스트 전 항목 통과

## references/ 목록

| 파일 | 설명 |
|---|---|
| `slice-tests.md` | `@WebMvcTest`, `@DataJpaTest`, `@JsonTest`, `@SpringBootTest` 범위와 패턴 |
| `testcontainers.md` | TestContainers 설정, 컨테이너 재사용, 테스트 컨텍스트 캐싱 |
| `fixtures.md` | 빌더 패턴, ObjectMother, Faker 사용 기준, AssertJ 비교 |
