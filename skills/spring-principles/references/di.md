# DI — 생성자 주입 원칙

## 1) 규칙

- 모든 의존성은 **생성자 주입** + `private final` 필드.
- 단일 생성자: `@RequiredArgsConstructor` (Lombok) 사용.
- 복수 생성자: 명시 생성자를 직접 작성하고 `@Bean` 팩토리에서 조합.

```java
// 권장
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentClient paymentClient;
}
```

## 2) 왜 생성자 주입인가

- **불변성**: `final` 필드는 한 번 설정되면 교체 불가 → 부작용 없음.
- **테스트 용이**: `new OrderService(mockRepo, mockClient)` 로 프레임워크 없이 단위 테스트 가능.
- **순환 참조 조기 발견**: 필드/세터 주입은 런타임 오류, 생성자 주입은 시작 시점 오류.

## 3) 순환 참조 탐지 & 해결

순환 참조(`A → B → A`)가 발생하면 애플리케이션 시작 실패.

**접근법**:
1. 순환 구조 자체를 의심한다 — 책임 분리 위반 신호.
2. 공통 의존성을 별도 Service/Component로 추출한다.
3. `@Lazy`는 임시방편 — 근본 해결책이 아님.

```
A → B → A  (순환)
↓ 리팩터링
A → C ← B  (C: 공통 로직 추출)
```

## 4) 금지 패턴

```java
// 금지 — 필드 주입
@Autowired
private OrderRepository orderRepository;

// 금지 — 세터 주입 (테스트 외)
@Autowired
public void setOrderRepository(OrderRepository repo) { ... }
```

## 관련 원칙

- [anti-patterns.md](./anti-patterns.md) — 필드 주입 안티패턴
- [testability.md](./testability.md) — new 직접 생성 가능 설계
