# 테스트 픽스처 가이드

테스트 데이터를 명시적이고 재사용 가능하게 구성하는 패턴.
빌더, ObjectMother, Faker 사용 기준과 AssertJ 비교 방법을 다룬다.

---

## 1) 왜 픽스처가 중요한가

```java
// 안티패턴: 테스트마다 Entity 직접 조립
Member member = new Member();
member.setEmail("test" + UUID.randomUUID() + "@example.com");
member.setPassword("pw");
member.setStatus(MemberStatus.ACTIVE);
member.setCreatedAt(LocalDateTime.now());
```

이 방식의 문제:
- 필드를 하나 추가할 때 모든 테스트에서 생성 코드를 수정해야 함
- `UUID.randomUUID()`로 실패 재현이 어려움
- 어떤 상태가 **테스트에서 중요한 것인지** 코드에서 드러나지 않음

---

## 2) 빌더 패턴 (Test Data Builder)

도메인 객체마다 빌더를 두고, 합리적 기본값을 설정한다.
테스트에서는 **검증에 중요한 필드만** 덮어쓴다.

```java
public class MemberBuilder {

    private Long id = 1L;
    private String email = "test@example.com";
    private String password = "{bcrypt}$2a$10$testEncodedPassword";
    private MemberStatus status = MemberStatus.ACTIVE;
    private LocalDateTime createdAt = LocalDateTime.of(2024, 1, 1, 0, 0);

    public static MemberBuilder aMember() { return new MemberBuilder(); }

    public MemberBuilder id(Long id)             { this.id = id; return this; }
    public MemberBuilder email(String email)     { this.email = email; return this; }
    public MemberBuilder password(String password) { this.password = password; return this; }
    public MemberBuilder status(MemberStatus s)  { this.status = s; return this; }

    public Member build() {
        return Member.builder()
            .id(id)
            .email(email)
            .password(password)
            .status(status)
            .createdAt(createdAt)
            .build();
    }
}
```

**사용 예시**

```java
// 기본값 그대로
Member member = MemberBuilder.aMember().build();

// 검증 포인트만 명시
Member other = MemberBuilder.aMember()
    .email("other@example.com")
    .status(MemberStatus.LOCKED)
    .build();
```

**테스트가 어떤 상태를 검증하는지 코드에서 즉시 파악된다.**

---

## 3) ObjectMother

시나리오 의미를 이름으로 드러내는 정적 팩토리. 빌더와 상호 보완한다.

```java
public class MemberFixtures {

    public static Member aActiveMember() {
        return MemberBuilder.aMember()
            .status(MemberStatus.ACTIVE)
            .build();
    }

    public static Member aLockedMember() {
        return MemberBuilder.aMember()
            .status(MemberStatus.LOCKED)
            .build();
    }

    public static Member anUnverifiedMember() {
        return MemberBuilder.aMember()
            .status(MemberStatus.UNVERIFIED)
            .email("unverified@example.com")
            .build();
    }

    public static MemberBuilder aMember() {
        return MemberBuilder.aMember();  // 세부 조정이 필요하면 빌더 노출
    }
}
```

**사용 예시**

```java
// 시나리오 이름만 봐도 무엇을 검증하는지 명확
@Test
void 잠긴_계정은_로그인_실패() {
    Member locked = MemberFixtures.aLockedMember();
    // ...
}

@Test
void 이메일_중복_등록_실패() {
    Member existing = MemberFixtures.aMember()
        .email("duplicate@example.com")
        .build();
    // ...
}
```

---

## 4) 빌더 vs ObjectMother 선택 기준

| 상황 | 선택 |
|---|---|
| 특정 필드 값이 테스트의 핵심 | 빌더 — `.email("...").build()` |
| 도메인 상태 자체가 테스트의 전제 | ObjectMother — `aLockedMember()` |
| 다양한 조합이 필요 | 빌더를 ObjectMother 내부에서 활용 |

하나만 선택하지 않아도 된다. ObjectMother가 내부적으로 빌더를 사용하면 양쪽의 장점을 모두 취한다.

---

## 5) Faker 사용 기준

Faker(`java-faker`, Kotlin `kotlin-faker` 등)는 랜덤 데이터를 생성하는 라이브러리다.

**허용하는 경우**

```java
// 이메일 형식 자체를 검증하는 테스트
@Test
void 유효한_이메일_형식은_등록_성공() {
    String validEmail = faker.internet().emailAddress();  // 형식이 중요, 값은 무관
    // ...
}

// 부하 테스트·시드 데이터 생성 (반복 실행 시 다양성 필요)
List<Member> seedMembers = IntStream.range(0, 1000)
    .mapToObj(i -> MemberBuilder.aMember()
        .email(faker.internet().emailAddress())
        .build())
    .toList();
```

**금지하는 경우**

```java
// 금지: 검증에 사용할 값을 랜덤으로
String expectedEmail = faker.internet().emailAddress();
memberService.register(expectedEmail, "Password1!");
// 실패 시 재현 불가 — 어떤 이메일이었는지 모름

// 금지: ID를 랜덤으로 (조회 연결이 끊어짐)
Long id = faker.number().randomNumber();
Member member = MemberBuilder.aMember().id(id).build();
repository.findById(id);  // 저장하지 않았으므로 항상 empty
```

**랜덤 사용 시 시드 고정으로 재현성 확보**

```java
Faker faker = new Faker(new Random(42L));  // 시드 고정 → 항상 동일 값
```

---

## 6) AssertJ 비교 패턴

**기본 비교**

```java
assertThat(actual.getEmail()).isEqualTo("test@example.com");
assertThat(actual.getStatus()).isEqualTo(MemberStatus.ACTIVE);
```

**필드 단위 재귀 비교** — `equals()`가 없는 객체, 일부 필드만 비교할 때

```java
assertThat(actual)
    .usingRecursiveComparison()
    .ignoringFields("id", "createdAt", "updatedAt")  // 자동 생성 가변 필드 제외
    .isEqualTo(expected);
```

**컬렉션 비교**

```java
assertThat(members)
    .hasSize(2)
    .extracting(Member::getEmail)
    .containsExactlyInAnyOrder("a@example.com", "b@example.com");
```

**예외 검증**

```java
assertThatThrownBy(() -> memberService.findById(999L))
    .isInstanceOf(MemberNotFoundException.class)
    .hasMessageContaining("999");
```

---

## 7) 안티패턴

```java
// 금지: 테스트마다 Entity 필드 직접 조립
Member member = new Member();
member.setEmail("test@example.com");
member.setPassword("raw");  // 인코딩 없이

// 금지: 무의미한 UUID 남발
String email = UUID.randomUUID() + "@test.com";  // 실패 재현 불가

// 금지: ObjectMother 없이 상태를 조건문으로 분기
Member member;
if (needsLocked) {
    member = new Member(LOCKED);
} else {
    member = new Member(ACTIVE);
}
// → aLockedMember() / aActiveMember() 로 대체

// 금지: 프로덕션 코드의 builder를 직접 테스트에서 호출 후 무관한 필드까지 설정
Member.builder()
    .id(1L).email("a@b.com").password("pw").role(ADMIN)
    .phone("010-0000-0000").address("서울시...")  // 이 테스트와 무관
    .build();
```

---

## 요약 체크리스트

- [ ] 도메인 객체마다 Test Data Builder 또는 ObjectMother 존재
- [ ] 기본값으로 합리적인 유효 객체를 반환 (필드마다 null/empty 없음)
- [ ] 테스트에서 검증과 무관한 필드 설정 코드 없음 (기본값으로 위임)
- [ ] Faker 사용 시 검증 대상 값이 아닌 형식·다양성 목적으로만
- [ ] 재현 필요한 시나리오에 시드 고정 또는 명시적 상수 사용
- [ ] AssertJ `usingRecursiveComparison().ignoringFields(...)`으로 가변 필드 제외
