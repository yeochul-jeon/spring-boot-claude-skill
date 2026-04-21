# Value Object 변환

## Before

```java
// Primitive Obsession
@Entity
public class Product {
    @Id @GeneratedValue
    private Long id;
    private String name;
    private long price;      // 음수? 0 허용? 통화는? 모름
    private String currency; // price와 항상 같이 다녀야 하지만 분리됨
}

@Service
public class OrderService {
    public void validatePrice(long price, String currency) {
        if (price < 0) throw new IllegalArgumentException("음수 불가");
        if (currency == null || currency.isBlank()) throw new IllegalArgumentException("통화 필요");
        // 이 검사가 여러 Service에 중복됨
    }
}
```

## After

```java
// Value Object — Java record 활용
public record Money(long amount, String currency) {

    public Money {
        if (amount < 0) throw new IllegalArgumentException("금액은 0 이상이어야 합니다.");
        if (currency == null || currency.isBlank()) throw new IllegalArgumentException("통화는 필수입니다.");
    }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException("통화가 다릅니다: " + this.currency + " vs " + other.currency);
        }
        return new Money(this.amount + other.amount, this.currency);
    }

    public boolean isGreaterThan(Money other) {
        if (!this.currency.equals(other.currency)) throw new IllegalArgumentException("통화 불일치");
        return this.amount > other.amount;
    }
}

// Entity — VO 사용
@Entity
public class Product {
    @Id @GeneratedValue
    private Long id;
    private String name;

    @Embedded
    private Money price;  // 유효성 검사가 VO 내부에 집중됨
}

// Service — 검사 중복 제거
@Service
public class OrderService {
    public void applyDiscount(Money original, Money discount) {
        if (discount.isGreaterThan(original)) {
            throw new IllegalArgumentException("할인금액이 원가를 초과할 수 없습니다.");
        }
        // ...
    }
}
```

## 왜

원시 타입으로 도메인 개념을 표현하면 유효성 검사가 여러 곳에 중복 작성되고, 같은 타입(`long`)이지만 의미가 다른 값들이 컴파일러 수준에서 구별되지 않는다. VO는 자신의 불변식을 생성 시점에 강제하므로 "잘못된 Money"가 시스템 내에 존재할 수 없게 된다.

## 관련 원칙

- [references/rich-domain.md](../references/rich-domain.md) — VO 도입 기준
- [references/anti-patterns.md](../references/anti-patterns.md) — Primitive Obsession 안티패턴
