# Rich Domain Model

## 1) Anemic vs Rich

| | Anemic (안티패턴) | Rich (권장) |
|---|---|---|
| Entity | 필드 + getter/setter만 | 필드 + 비즈니스 메서드 |
| 비즈니스 규칙 위치 | Service | Entity/VO 내부 |
| 문제 | 도메인 로직 분산, Service 비대화 | — |

## 2) Entity에 행위 부여

```java
// Anemic (금지)
@Entity
public class Order {
    private OrderStatus status;
    public void setStatus(OrderStatus status) { this.status = status; }
}

// Service에서 상태 전이 (안티패턴)
public void cancel(Long orderId) {
    Order order = orderRepository.findById(orderId).orElseThrow();
    if (order.getStatus() != OrderStatus.PENDING) throw new IllegalStateException();
    order.setStatus(OrderStatus.CANCELLED);
}
```

```java
// Rich (권장)
@Entity
public class Order {
    private OrderStatus status;

    public void cancel() {
        if (this.status != OrderStatus.PENDING) {
            throw new IllegalStateException("PENDING 상태만 취소 가능");
        }
        this.status = OrderStatus.CANCELLED;
    }
}

// Service: 오케스트레이션만
public void cancel(Long orderId) {
    Order order = orderRepository.findById(orderId).orElseThrow();
    order.cancel();  // 규칙은 Entity 내부
}
```

## 3) Value Object (VO) 도입

Primitive obsession — 원시 타입으로 도메인 개념을 표현하면 유효성 검사가 분산된다.

```java
// Primitive obsession (안티패턴)
public class Product {
    private long price;   // 음수? 통화? 알 수 없음
}

// VO 도입 (권장)
public record Money(long amount, Currency currency) {
    public Money {
        if (amount < 0) throw new IllegalArgumentException("금액은 0 이상");
    }
    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) throw new IllegalArgumentException("통화 불일치");
        return new Money(this.amount + other.amount, this.currency);
    }
}
```

## 4) VO 도입 기준

다음 중 하나라도 해당하면 VO 추출을 검토한다:
- 여러 클래스에서 같은 유효성 검사를 반복한다.
- 같은 타입(예: `String`)이지만 의미가 다르다 (이메일 vs 이름).
- 연산(덧셈, 비교)이 도메인 의미를 가진다.

## 5) Entity 불변성 유지

- setter를 public으로 열지 않는다. 상태 전이는 의미 있는 메서드명으로 표현.
- JPA 요구 기본 생성자는 `protected`로 숨긴다.

```java
@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member {
    @Id @GeneratedValue
    private Long id;
    private Email email;   // VO
    private String encodedPassword;

    public static Member create(String rawEmail, String encodedPassword) {
        Member m = new Member();
        m.email = new Email(rawEmail);
        m.encodedPassword = encodedPassword;
        return m;
    }
}
```

## 관련 원칙

- [anti-patterns.md](./anti-patterns.md) — Anemic domain 안티패턴
- [testability.md](./testability.md) — VO는 순수 객체이므로 단위 테스트 용이
