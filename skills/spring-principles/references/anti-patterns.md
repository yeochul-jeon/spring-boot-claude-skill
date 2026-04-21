# Spring 안티패턴 목록

## 1) 필드 주입 (`@Autowired` private field)

**문제**: 불변성 없음, 프레임워크 없이 테스트 불가, 순환 참조 탐지 지연.

```java
// 금지
@Service
public class OrderService {
    @Autowired
    private OrderRepository orderRepository;  // ← 필드 주입
}
```

→ `templates/constructor-injection.md` 참조.

---

## 2) Controller → Repository 직통 호출

**문제**: Service 계층 우회 → 트랜잭션 미보장, 비즈니스 로직 분산.

```java
// 금지
@RestController
@RequiredArgsConstructor
public class OrderController {
    private final OrderRepository orderRepository;  // ← Controller에 Repository 주입

    @GetMapping("/orders/{id}")
    public Order getOrder(@PathVariable Long id) {
        return orderRepository.findById(id).orElseThrow();  // ← Entity 직접 반환도 문제
    }
}
```

→ `templates/dto-entity-separation.md` 참조.

---

## 3) Entity 직접 반환 / 수신

**문제**: API 계약이 DB 스키마에 종속됨, 무한 순환 직렬화(`@JsonIgnore`로 땜질하는 징후).

```java
// 금지
@GetMapping("/members/{id}")
public Member getMember(@PathVariable Long id) {   // ← Entity 반환
    return memberService.findById(id);
}
```

→ `templates/dto-entity-separation.md` 참조.

---

## 4) Anemic Domain Model

**문제**: 비즈니스 로직이 Service에 집중 → Service 비대화, 도메인 규칙 분산.

```java
// 금지 — 상태 전이 로직이 Service에 있음
public void approve(Long orderId) {
    Order order = orderRepository.findById(orderId).orElseThrow();
    if (order.getStatus() != PENDING) throw new IllegalStateException();
    order.setStatus(APPROVED);  // setter 남용
    order.setApprovedAt(LocalDateTime.now());
}
```

→ `templates/rich-domain.md`, `references/rich-domain.md` 참조.

---

## 5) `@Transactional` 남용 / 누락

**남용**: Controller에 `@Transactional` 선언, 조회 메서드에 쓰기 트랜잭션.

**누락**: 데이터 변경 Service 메서드에 `@Transactional` 없음 → Dirty Checking 미작동.

```java
// 금지 — Controller에 @Transactional
@Transactional
@PostMapping("/orders")
public ResponseEntity<OrderResponse> create(...) { ... }

// 권장 — Service에 정확히 배치
@Service
@Transactional(readOnly = true)
public class OrderService {
    @Transactional
    public OrderResponse create(OrderCreateRequest request) { ... }

    public OrderResponse findById(Long id) { ... }  // readOnly 상속
}
```

→ `references/separation-of-concerns.md` 참조.

---

## 6) 반복 try-catch-finally (횡단 관심사 누출)

**문제**: 동일한 예외 처리·로깅·트랜잭션 코드가 여러 메서드에 중복.

```java
// 금지
public void processA() {
    try { ... }
    catch (Exception e) { log.error(...); throw ...; }
    finally { cleanup(); }
}
public void processB() {
    try { ... }
    catch (Exception e) { log.error(...); throw ...; }
    finally { cleanup(); }
}
```

→ `templates/template-method-pattern.md` 참조.

---

## 7) Primitive Obsession

**문제**: `long price`, `String email` 등 원시 타입으로 도메인 개념 표현 → 유효성 검사 중복, 의미 불명확.

→ `templates/value-object.md`, `references/rich-domain.md` 참조.
