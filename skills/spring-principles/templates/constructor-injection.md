# 생성자 주입 변환

## Before

```java
@Service
public class OrderService {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private PaymentClient paymentClient;

    public OrderResponse create(OrderCreateRequest request) {
        // ...
    }
}
```

## After

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final PaymentClient paymentClient;

    public OrderResponse create(OrderCreateRequest request) {
        // ...
    }
}
```

## 왜

필드 주입은 `final`을 사용할 수 없어 의존성이 교체될 위험이 있고, Spring 컨테이너 없이는 단위 테스트 시 `new OrderService()`로 직접 생성할 수 없다. 생성자 주입은 불변성과 테스트 용이성을 동시에 보장하며, 순환 참조를 애플리케이션 시작 시점에 즉시 발견할 수 있다.

## 관련 원칙

- [references/di.md](../references/di.md)
- [references/testability.md](../references/testability.md)
