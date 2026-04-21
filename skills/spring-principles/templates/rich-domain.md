# Rich Domain Model 변환

## Before

```java
// Anemic Entity — setter만 있음
@Entity
@Getter @Setter
public class Order {
    @Id @GeneratedValue
    private Long id;
    private OrderStatus status;
    private LocalDateTime cancelledAt;
}

// 비즈니스 로직이 Service에
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;

    @Transactional
    public void cancel(Long orderId) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        // 도메인 규칙이 Service에 누출됨
        if (order.getStatus() != OrderStatus.PENDING) {
            throw new IllegalStateException("취소 불가 상태: " + order.getStatus());
        }
        order.setStatus(OrderStatus.CANCELLED);
        order.setCancelledAt(LocalDateTime.now());
    }
}
```

## After

```java
// Rich Entity — 행위를 가짐
@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Order {
    @Id @GeneratedValue
    private Long id;
    private OrderStatus status;
    private LocalDateTime cancelledAt;

    public static Order create() {
        Order order = new Order();
        order.status = OrderStatus.PENDING;
        return order;
    }

    // 도메인 규칙이 Entity 내부에
    public void cancel() {
        if (this.status != OrderStatus.PENDING) {
            throw new IllegalStateException("PENDING 상태만 취소 가능합니다.");
        }
        this.status = OrderStatus.CANCELLED;
        this.cancelledAt = LocalDateTime.now();
    }
}

// Service — 오케스트레이션만 담당
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;

    @Transactional
    public void cancel(Long orderId) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        order.cancel();  // 규칙은 Entity가 책임
    }
}
```

## 왜

비즈니스 규칙을 Service에 두면 같은 규칙이 여러 Service 메서드에 흩어지고, Entity가 자신의 불변식을 스스로 보장할 수 없다. Rich Entity는 상태 전이를 캡슐화하여 "잘못된 상태로의 전이"를 컴파일 타임과 런타임 모두에서 방어한다.

## 관련 원칙

- [references/rich-domain.md](../references/rich-domain.md)
- [references/anti-patterns.md](../references/anti-patterns.md)
