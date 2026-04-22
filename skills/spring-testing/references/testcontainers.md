# TestContainers 가이드

통합 테스트에서 실제 DB·미들웨어를 Docker 컨테이너로 실행하는 표준 패턴.
H2 인메모리 DB를 대체하고 운영 환경과 동일한 조건에서 검증한다.

---

## 1) 왜 TestContainers인가

H2 인메모리 DB는 빠르지만 운영 DB와 **방언(dialect)·제약·함수 차이**가 있다.

| 구분 | H2 | MySQL / PostgreSQL |
|---|---|---|
| `ON DUPLICATE KEY UPDATE` | 미지원 | MySQL 지원 |
| JSON 컬럼·함수 | 부분 에뮬레이션 | 완전 지원 |
| 인덱스 힌트 | 무시 | 적용 |
| UUID 자동 생성 함수 | 다름 | DB별 네이티브 |

운영에서 터지는 쿼리 오류를 테스트 단계에 잡으려면 **동일 엔진** 사용이 필수다.

---

## 2) 기본 설정 — MySQL

```kotlin
// build.gradle.kts
dependencies {
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:mysql")
}
```

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)
@Testcontainers
class MemberRepositoryTest {

    @Container
    static MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test")
        .withReuse(true);   // 컨테이너 재사용 — 로컬 빌드 속도 핵심

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url",      MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
        registry.add("spring.datasource.driver-class-name", () -> "com.mysql.cj.jdbc.Driver");
    }
}
```

---

## 3) 기본 설정 — PostgreSQL

```kotlin
// build.gradle.kts
testImplementation("org.testcontainers:postgresql")
```

```java
@Container
static PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16")
    .withReuse(true);

@DynamicPropertySource
static void registerProps(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url",      POSTGRES::getJdbcUrl);
    registry.add("spring.datasource.username", POSTGRES::getUsername);
    registry.add("spring.datasource.password", POSTGRES::getPassword);
}
```

---

## 4) 컨테이너 재사용 (withReuse)

컨테이너를 테스트마다 새로 띄우면 로컬 빌드가 수십 초씩 느려진다.
`withReuse(true)`를 설정하면 같은 설정의 컨테이너를 재사용한다.

**활성화 방법**

```properties
# ~/.testcontainers.properties (홈 디렉터리에 생성)
testcontainers.reuse.enable=true
```

```java
// 컨테이너 선언에도 명시
static MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
    .withReuse(true);
```

**재사용 메커니즘**: Testcontainers가 컨테이너 설정의 해시를 계산해 동일한 컨테이너가
이미 실행 중이면 재사용. JVM 재시작 후에도 Docker 컨테이너가 살아있으면 재사용한다.

**주의**: `withReuse(true)` 사용 시 **테스트 간 데이터가 누적**된다.
각 테스트는 `@Transactional`(롤백) 또는 `@Sql(scripts = "cleanup.sql")`로
데이터를 정리해야 한다.

---

## 5) 테스트 컨텍스트 캐싱

Spring 테스트 컨텍스트는 동일 설정이면 캐싱·재사용한다. `@MockitoBean`이 하나라도
다르면 **새 컨텍스트가 생성**되어 부팅 시간이 늘어난다.

**공통 기반 클래스로 묶기**

```java
// 공통 설정을 추상 클래스로 분리 — 모든 @DataJpaTest가 이 클래스를 상속
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)
@Testcontainers
abstract class AbstractRepositoryTest {

    @Container
    static MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0").withReuse(true);

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url",      MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
    }
}

// 개별 Repository 테스트
class MemberRepositoryTest extends AbstractRepositoryTest {
    @Autowired MemberRepository memberRepository;
    // ...
}
```

**`@DirtiesContext`는 최후 수단**

```java
// 금지: 불필요한 컨텍스트 재생성
@DirtiesContext(classMode = AFTER_EACH_TEST_METHOD)  // 매 테스트마다 컨텍스트 재생성

// 권장: 데이터만 정리
@Transactional  // 또는
@Sql(scripts = "/cleanup.sql", executionPhase = AFTER_TEST_METHOD)
```

---

## 6) Redis 컨테이너

JWT Refresh Token, Spring Session 등 Redis 연동 테스트에 사용한다.

```kotlin
// build.gradle.kts
testImplementation("org.testcontainers:testcontainers")  // GenericContainer 포함
```

```java
@Container
static GenericContainer<?> REDIS = new GenericContainer<>("redis:7-alpine")
    .withExposedPorts(6379)
    .withReuse(true);

@DynamicPropertySource
static void registerRedisProps(DynamicPropertyRegistry registry) {
    registry.add("spring.data.redis.host", REDIS::getHost);
    registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
}
```

---

## 7) CI 환경 설정

CI(GitHub Actions 등)에서는 Docker-in-Docker 또는 Docker socket 마운트가 필요하다.

**GitHub Actions 예시**

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest  # Docker 기본 지원
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - run: ./gradlew test
```

`ubuntu-latest`에는 Docker가 기본 설치되어 TestContainers가 별도 설정 없이 동작한다.

**재사용 비활성화 (CI)**

CI에서는 컨테이너 재사용을 비활성화하는 것이 일반적이다 (상태 격리 목적).
`TESTCONTAINERS_REUSE_ENABLE=false` 환경변수로 오버라이드한다.

---

## 8) 안티패턴

```java
// 금지: H2 + @DataJpaTest (replace 미설정)
@DataJpaTest
// @AutoConfigureTestDatabase(replace = NONE) 없음 → H2 자동 사용

// 금지: 테스트마다 새 컨테이너 (static 없음)
@Container
MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0");  // static 누락 → 매 테스트 재시작

// 금지: 운영 DB와 다른 이미지 버전
new MySQLContainer<>("mysql:5.7")  // 운영이 8.0이면 불일치
```

---

## 요약 체크리스트

- [ ] `@AutoConfigureTestDatabase(replace = NONE)` 적용 (`@DataJpaTest` 사용 시)
- [ ] 컨테이너는 `static` 필드로 선언 (테스트 클래스당 1개)
- [ ] `withReuse(true)` + `~/.testcontainers.properties` 로컬 재사용 설정
- [ ] 공통 컨테이너를 추상 기반 클래스로 묶어 컨텍스트 캐시 히트율 향상
- [ ] 컨테이너 이미지 버전이 운영 DB 버전과 일치
- [ ] 데이터 격리 — `@Transactional` 롤백 또는 cleanup SQL 적용
- [ ] `@DirtiesContext`는 불가피한 경우에만
