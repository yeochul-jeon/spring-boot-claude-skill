# Bean Validation

## 1) 의존성 확인

`spring-boot-starter-validation`이 `build.gradle.kts`에 포함되어야 한다.

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-validation")
}
```

## 2) 표준 어노테이션 카탈로그

### 문자열

| 어노테이션 | 설명 |
|---|---|
| `@NotNull` | null 불허 (빈 문자열은 허용) |
| `@NotBlank` | null·빈 문자열·공백만인 문자열 불허 |
| `@NotEmpty` | null·빈 문자열 불허 (공백만 허용) |
| `@Size(min, max)` | 문자열 길이, 컬렉션 크기 범위 |
| `@Email` | 이메일 형식 검증 |
| `@Pattern(regexp)` | 정규식 매칭 |

### 숫자

| 어노테이션 | 설명 |
|---|---|
| `@Min(value)` | 최솟값 (정수형) |
| `@Max(value)` | 최댓값 (정수형) |
| `@Positive` | 양수 (`> 0`) |
| `@PositiveOrZero` | 0 이상 |
| `@Negative` | 음수 |
| `@DecimalMin` / `@DecimalMax` | 소수 포함 범위 |
| `@Digits(integer, fraction)` | 정수부·소수부 자릿수 |

### 기타

| 어노테이션 | 설명 |
|---|---|
| `@Future` / `@Past` | 미래·과거 날짜 |
| `@FutureOrPresent` / `@PastOrPresent` | 현재 포함 |
| `@AssertTrue` / `@AssertFalse` | boolean 값 검증 |

## 3) `@Valid` vs `@Validated`

| | `@Valid` | `@Validated` |
|---|---|---|
| 출처 | Jakarta Bean Validation | Spring |
| Validation Group 지원 | ❌ | ✅ |
| 중첩 객체 검증(`@Valid` 필드) | ✅ | ✅ |
| 사용 위치 | Controller `@RequestBody`, 메서드 파라미터 | 클래스 레벨 (`@RequestParam`, `@PathVariable`) |

```java
// @RequestBody → @Valid
@PostMapping
public ResponseEntity<MemberResponse> register(
    @RequestBody @Valid MemberRegisterRequest request) { ... }

// Path/Query 파라미터 → 클래스에 @Validated
@RestController
@Validated
public class ProductController {

    @GetMapping("/{id}")
    public ProductResponse findById(
        @PathVariable @Positive Long id) { ... }
}
```

## 4) Validation Group

같은 DTO를 생성·수정에 재사용할 때 그룹으로 분기.

```java
// 그룹 마커 인터페이스
public interface OnCreate {}
public interface OnUpdate {}

// DTO
public record ProductRequest(
    @NotBlank(groups = OnCreate.class) String name,
    @NotNull(groups = {OnCreate.class, OnUpdate.class}) @Positive BigDecimal price
) {}

// Controller
@PostMapping
public ResponseEntity<ProductResponse> create(
    @RequestBody @Validated(OnCreate.class) ProductRequest request) { ... }

@PutMapping("/{id}")
public ProductResponse update(
    @PathVariable Long id,
    @RequestBody @Validated(OnUpdate.class) ProductRequest request) { ... }
```

## 5) 커스텀 Validator

```java
// 어노테이션 정의
@Target({FIELD, PARAMETER})
@Retention(RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
public @interface PhoneNumber {
    String message() default "전화번호 형식이 올바르지 않습니다";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

// 구현체
public class PhoneNumberValidator implements ConstraintValidator<PhoneNumber, String> {
    private static final Pattern PATTERN = Pattern.compile("^\\d{2,3}-\\d{3,4}-\\d{4}$");

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null) return true;  // @NotNull이 null 검사 담당
        return PATTERN.matcher(value).matches();
    }
}

// 사용
public record ContactRequest(
    @PhoneNumber String phone
) {}
```

## 6) 에러 메시지 i18n

`src/main/resources/ValidationMessages.properties` 파일 생성:

```properties
member.email.required=이메일은 필수입니다
member.password.minLength=비밀번호는 최소 {min}자 이상이어야 합니다
```

DTO에서 참조:
```java
@NotBlank(message = "{member.email.required}")
@Email
String email,

@Size(min = 8, message = "{member.password.minLength}")
String password
```

## 관련 원칙

- [exception-handling.md](./exception-handling.md) — `MethodArgumentNotValidException` 처리
- [dto-patterns.md](./dto-patterns.md) — DTO에 validation 어노테이션 위치
