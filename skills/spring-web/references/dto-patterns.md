# DTO Patterns

## 1) 원칙

- **Request DTO**: 클라이언트 → 서버 입력. Bean Validation 어노테이션 적용.
- **Response DTO**: 서버 → 클라이언트 출력. Entity 내부를 숨기는 뷰 객체.
- Entity를 Controller 메서드 반환 타입이나 `@RequestBody` 타입으로 쓰지 않는다.

상세 이유: `spring-principles/templates/dto-entity-separation.md` 참조.

## 2) Java Record 활용

Java 21 기준 record를 기본으로 사용한다. 불변·`equals`·`hashCode`·`toString` 자동 생성.

```java
// 입력 DTO — validation 어노테이션 포함
public record MemberRegisterRequest(
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "이메일 형식이 올바르지 않습니다")
    String email,

    @NotBlank(message = "비밀번호는 필수입니다")
    @Size(min = 8, message = "비밀번호는 8자 이상이어야 합니다")
    String password
) {}

// 출력 DTO — static factory로 Entity 변환
public record MemberResponse(Long id, String email, LocalDateTime createdAt) {
    public static MemberResponse from(Member member) {
        return new MemberResponse(
            member.getId(),
            member.getEmail(),
            member.getCreatedAt()
        );
    }
}
```

## 3) Entity ↔ DTO 매핑 전략 비교

| 방식 | 장점 | 단점 | 선택 기준 |
|---|---|---|---|
| **Static factory** (`from()`) | 의존성 없음, 명시적, 디버깅 쉬움 | 필드 많으면 코드 반복 | 기본 선택. 프로젝트 초기·소규모 |
| **MapStruct** | 자동 생성, 컴파일 타임 검증 | 설정 복잡, 어노테이션 학습 필요 | 매핑 코드가 많아질 때 도입 |

MapStruct 도입 시 `libs.versions.toml` 에 버전 추가 필요 (`spring-init/references/gradle-conventions.md` 참조).

```kotlin
// build.gradle.kts — MapStruct 추가 예시
implementation(libs.mapstruct.core)
annotationProcessor(libs.mapstruct.processor)
```

## 4) 중첩 DTO

연관 객체가 있으면 중첩 record로 표현. Entity 중첩 반환 금지.

```java
public record OrderResponse(
    Long id,
    OrderStatus status,
    List<OrderItemResponse> items,
    MoneyResponse totalPrice
) {
    public record OrderItemResponse(Long productId, String productName, int quantity) {}
    public record MoneyResponse(long amount, String currency) {}

    public static OrderResponse from(Order order) {
        return new OrderResponse(
            order.getId(),
            order.getStatus(),
            order.getItems().stream().map(i ->
                new OrderItemResponse(i.getProductId(), i.getProductName(), i.getQuantity())
            ).toList(),
            new MoneyResponse(order.getTotalPrice().amount(), order.getTotalPrice().currency())
        );
    }
}
```

## 5) 직렬화 주의 사항

- `@JsonInclude(JsonInclude.Include.NON_NULL)` — null 필드 제외 (공통 설정은 `application.yml` jackson 옵션으로).
- `LocalDateTime` 직렬화 포맷: `application.yml`에서 `spring.jackson.date-format` 또는 `@JsonFormat` 개별 지정.
- **`@JsonIgnore`를 Entity에 붙이지 않는다** — DTO 분리로 해결.

## 관련 원칙

- [spring-principles/templates/dto-entity-separation.md](../../spring-principles/templates/dto-entity-separation.md)
- [rest-conventions.md](./rest-conventions.md) — 응답 구조(페이지네이션 등)
