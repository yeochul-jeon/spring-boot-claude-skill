---
name: spring-persistence
description: Use when implementing a persistence layer in Spring Boot
  with either JPA/Hibernate or MyBatis. Trigger on "DB 연결", "엔티티 설계",
  "리포지토리", "Mapper", "트랜잭션 경계". The skill FIRST asks whether to
  use JPA or MyBatis (see references/selection-guide.md), then proceeds
  with the chosen path.
---

# Spring Persistence

Spring Boot 영속성 계층의 표준 패턴. JPA/MyBatis 선택 → 의존성 → 엔티티/Mapper → 트랜잭션 경계를
순서대로 확정하며, 코드 작성 완료 후 `spring-principles` 체크리스트로 자가 검증한다.

## 절대 원칙

1. **JPA/MyBatis를 가정하지 않는다.** `references/selection-guide.md`로 먼저 결정하고 사용자 승인을 받는다.
2. **`@Transactional`은 Service 계층에만.** Repository·Controller에 두지 않는다.
3. **DTO ↔ Entity 분리.** Entity를 Controller로 직접 반환하거나 요청 바디로 수신하지 않는다.
   (`spring-principles/templates/dto-entity-separation.md` 참조)
4. **DB 기본값은 MySQL.** PostgreSQL은 사용자가 명시한 경우에만 사용한다.

## 워크플로우

### 1. 구현 선택

`references/selection-guide.md`의 체크리스트로 JPA/MyBatis 선택.  
프롬프트에 이미 명시된 경우("JPA로 해줘", "MyBatis 써줘") 인터뷰 생략.  
불명확하면 체크리스트 분석 결과 + 추천을 제시하고 사용자 확인.

### 2. 의존성 추가

`build.gradle.kts`에 선택에 따라 추가:

**JPA 경로**

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    runtimeOnly("com.mysql:mysql-connector-j")                    // MySQL 기본
    // PostgreSQL 요청 시: runtimeOnly("org.postgresql:postgresql")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:mysql")                // DB 종류에 맞춰 변경
}
```

**MyBatis 경로**

```kotlin
dependencies {
    implementation("org.mybatis.spring.boot:mybatis-spring-boot-starter:${latestVersion}")
    runtimeOnly("com.mysql:mysql-connector-j")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:mysql")
}
```

> MyBatis starter 버전은 기억에 의존하지 말고 Maven Central에서 최신을 확인한다.

### 3. Entity / Mapper 작성

- **JPA**: `references/jpa.md` 패턴 — 연관관계 방향, 지연 로딩, Auditing
- **MyBatis**: `references/mybatis.md` 패턴 — Mapper 인터페이스, XML, ResultMap

### 4. Repository / Mapper 계층

**JPA**

```java
public interface MemberRepository extends JpaRepository<Member, Long> {
    Optional<Member> findByEmail(String email);
}
```

**MyBatis**

```java
@Mapper
public interface MemberMapper {
    Optional<Member> findById(Long id);
    void insert(Member member);
}
```

### 5. Service에 @Transactional 적용

`references/transaction.md` 참조.  
조회 메서드는 `@Transactional(readOnly = true)`, 변경 메서드는 `@Transactional`.

```java
@Service
@Transactional(readOnly = true)
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;

    @Transactional
    public MemberResponse register(MemberRegisterRequest request) { ... }

    public MemberResponse findById(Long id) { ... }
}
```

### 6. N+1 / Dynamic SQL 점검

- **JPA**: 컬렉션 조회에 fetch join 또는 `@EntityGraph` 적용 (`references/jpa.md` N+1 섹션)
- **MyBatis**: `<if>` / `<foreach>` 로 동적 SQL 처리, Java에서 SQL 문자열 조립 금지

### 7. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] JPA/MyBatis 선택을 사용자에게 확인했는가
- [ ] `@Transactional`이 Service 계층에만 위치 (Repository·Controller에 없음)
- [ ] Entity가 Controller 응답 타입으로 직접 노출되지 않음
- [ ] 생성자 주입 + `final` 필드 (필드 주입 없음)
- [ ] `testcontainers:mysql` (또는 해당 DB) 의존성 포함
- [ ] JPA 선택 시 연관관계 기본 `fetch = LAZY`, 컬렉션 조회에 fetch join / `@EntityGraph`
- [ ] MyBatis 선택 시 `<resultMap>` 사용, Java에서 SQL 문자열 조립 없음
- [ ] `spring-principles` 체크리스트 전 항목 통과

## references/ 목록

| 파일 | 설명 |
|---|---|
| `selection-guide.md` | JPA vs MyBatis 의사결정 체크리스트 (진입 시 첫 참조) |
| `jpa.md` | Entity 설계, 연관관계, N+1 회피, Auditing |
| `mybatis.md` | Mapper 인터페이스, XML, Dynamic SQL, ResultMap |
| `transaction.md` | `@Transactional` 경계, readOnly, 전파 속성 |
