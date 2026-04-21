# 슬라이스 테스트 가이드

`@WebMvcTest`, `@DataJpaTest`, `@JsonTest`, `@SpringBootTest`의 범위와 목적.
풀 컨텍스트를 띄우기 전에 가장 좁은 슬라이스부터 선택한다.

---

## 1) 슬라이스 매트릭스

| 어노테이션 | 로드하는 Bean | 제외되는 Bean | 주요 용도 |
|---|---|---|---|
| `@WebMvcTest` | Controller, Filter, MVC 설정 | Service, Repository, DB | HTTP 입출력·검증 |
| `@DataJpaTest` | JPA Entity, Repository, DataSource | Controller, Service | 쿼리·제약 검증 |
| `@DataJdbcTest` | JDBC, DataSource | Controller, Service | MyBatis Mapper 쿼리 검증 |
| `@JsonTest` | Jackson 설정 | 나머지 전부 | 직렬화·역직렬화 |
| `@SpringBootTest` | 전체 컨텍스트 | 없음 | E2E 통합 플로우 |

슬라이스를 선택하는 기준: **"지금 검증하려는 것이 어느 계층인가?"**

---

## 2) @WebMvcTest

**목적**: Controller 계층 단독 검증. Service는 `@MockBean`으로 대체한다.

```java
@WebMvcTest(MemberController.class)  // 대상 Controller 명시 — 전체 스캔 방지
class MemberControllerTest {

    @Autowired
    MockMvc mockMvc;

    @Autowired
    ObjectMapper objectMapper;

    @MockBean
    MemberService memberService;

    @Test
    @WithMockUser  // spring-security 연동 시 인증 우회
    void 회원_단건_조회_성공() throws Exception {
        MemberResponse response = new MemberResponse(1L, "test@example.com");
        given(memberService.findById(1L)).willReturn(response);

        mockMvc.perform(get("/api/v1/members/1")
                   .contentType(MediaType.APPLICATION_JSON))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.id").value(1L))
               .andExpect(jsonPath("$.email").value("test@example.com"));
    }

    @Test
    @WithMockUser
    void 회원_등록_요청_바디_검증_실패() throws Exception {
        String body = objectMapper.writeValueAsString(new MemberRegisterRequest("", "pw"));

        mockMvc.perform(post("/api/v1/members")
                   .contentType(MediaType.APPLICATION_JSON)
                   .content(body))
               .andExpect(status().isBadRequest());
    }
}
```

**Security가 있을 때**

- `@WithMockUser`: 기본 ROLE_USER 인증 통과
- `@WithMockUser(roles = "ADMIN")`: 특정 역할 필요 엔드포인트
- SecurityConfig Bean이 `@WebMvcTest`에 로드되지 않으면 `@Import(SecurityConfig.class)` 추가

**안티패턴**

```java
// 금지: Controller 명시 없이 전체 스캔
@WebMvcTest  // ← 모든 Controller 로드 → 불필요한 의존성 + 느린 부팅

// 금지: @SpringBootTest로 Controller 테스트
@SpringBootTest
@AutoConfigureMockMvc  // 슬라이스가 존재하는데 풀 컨텍스트 불필요
```

---

## 3) @DataJpaTest

**목적**: JPA Repository 쿼리, 제약 조건, 연관관계 로딩 검증.

기본적으로 H2 인메모리 DB를 자동 구성하지만 **운영 DB와 방언 차이가 생기므로
반드시 TestContainers와 함께 사용**한다.

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)  // H2 자동 치환 비활성화 — TestContainers DB 사용
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

    @Autowired
    MemberRepository memberRepository;

    @Autowired
    TestEntityManager entityManager;  // 사전 데이터 저장에 사용

    @Test
    void 이메일로_회원_조회() {
        entityManager.persistAndFlush(MemberFixtures.aMember().build());

        Optional<Member> found = memberRepository.findByEmail("test@example.com");

        assertThat(found).isPresent();
        assertThat(found.get().getEmail()).isEqualTo("test@example.com");
    }
}
```

**트랜잭션 동작**: `@DataJpaTest`는 각 테스트를 트랜잭션으로 감싸고 롤백한다.
단, `REQUIRES_NEW`로 선언된 메서드나 `@Commit`을 붙인 경우 롤백되지 않는다.

---

## 4) @JsonTest

**목적**: Jackson 직렬화·역직렬화 검증. `@JsonProperty`, 날짜 포맷, 커스텀
Serializer/Deserializer를 검증할 때 적합하다.

```java
@JsonTest
class MemberResponseJsonTest {

    @Autowired
    JacksonTester<MemberResponse> json;

    @Test
    void 직렬화_검증() throws Exception {
        MemberResponse response = new MemberResponse(1L, "test@example.com");

        JsonContent<MemberResponse> result = json.write(response);

        assertThat(result).hasJsonPathNumberValue("$.id", 1L);
        assertThat(result).hasJsonPathStringValue("$.email", "test@example.com");
        assertThat(result).doesNotHaveJsonPath("$.password");  // 민감 필드 노출 방지 확인
    }

    @Test
    void 역직렬화_검증() throws Exception {
        String content = "{\"id\":1,\"email\":\"test@example.com\"}";

        MemberResponse response = json.parse(content).getObject();

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.email()).isEqualTo("test@example.com");
    }
}
```

---

## 5) @SpringBootTest

**목적**: 슬라이스로 커버할 수 없는 E2E 통합 흐름. Controller → Service → Repository
전체를 실제 DB와 함께 검증할 때 사용한다.

**최소한으로 사용한다.** 모든 테스트를 `@SpringBootTest`로 작성하면 컨텍스트 부팅
비용이 누적되어 빌드가 느려진다.

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)  // 실제 포트 바인딩
@Testcontainers
class MemberIntegrationTest {

    @Container
    static MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0").withReuse(true);

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
    }

    @Autowired
    TestRestTemplate restTemplate;

    @Test
    void 회원_등록_조회_통합_플로우() {
        MemberRegisterRequest request = new MemberRegisterRequest("user@example.com", "Password1!");

        ResponseEntity<MemberResponse> created = restTemplate.postForEntity(
            "/api/v1/members", request, MemberResponse.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<MemberResponse> found = restTemplate.getForEntity(
            "/api/v1/members/" + created.getBody().id(), MemberResponse.class);
        assertThat(found.getBody().email()).isEqualTo("user@example.com");
    }
}
```

**`MockMvc` vs `TestRestTemplate`**

| | `MockMvc` | `TestRestTemplate` |
|---|---|---|
| 포트 바인딩 | 없음 (서블릿 모의) | 실제 포트 (`RANDOM_PORT`) |
| 필터/인터셉터 | 적용 | 적용 |
| 실제 네트워크 | ❌ | ✅ |
| 속도 | 빠름 | 느림 |

---

## 6) 안티패턴

```java
// 금지: 모든 테스트를 @SpringBootTest로 작성
@SpringBootTest  // 슬라이스로 충분한 테스트에 전체 컨텍스트 낭비

// 금지: @DataJpaTest에 replace 미설정 (H2 자동 치환)
@DataJpaTest
// replace = NONE 없음 → H2 사용 → 운영 DB 방언 차이 버그 은폐

// 금지: 불필요한 @MockBean 남발 — 컨텍스트 캐시 파괴
@WebMvcTest(MemberController.class)
@MockBean MemberRepository memberRepository;  // Controller 계층에 불필요, 캐시 미스 발생
```

---

## 요약 체크리스트

- [ ] 슬라이스 어노테이션을 목적에 맞게 선택 (`@WebMvcTest` / `@DataJpaTest` / `@JsonTest`)
- [ ] `@DataJpaTest`에 `@AutoConfigureTestDatabase(replace = NONE)` 적용
- [ ] `@WebMvcTest`에 대상 Controller 클래스 명시
- [ ] Security 연동 시 `@WithMockUser` 또는 `@Import(SecurityConfig.class)` 사용
- [ ] `@SpringBootTest`는 E2E 범위로 최소화, 슬라이스 대체 불가 케이스에만 사용
