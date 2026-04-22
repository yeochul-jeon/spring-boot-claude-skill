# Micrometer 메트릭

## 1) 메트릭 타입

| 타입 | 용도 | 예시 |
|------|------|------|
| `Counter` | 누적 횟수 | 주문 생성 건수, 에러 발생 횟수 |
| `Timer` | 실행 시간 분포 | API 응답 시간, DB 쿼리 시간 |
| `Gauge` | 현재 값 | 큐 사이즈, 활성 세션 수 |
| `DistributionSummary` | 값의 분포 | 결제 금액 분포 |

## 2) Counter

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final MeterRegistry meterRegistry;

    @Transactional
    public OrderResponse createOrder(OrderCreateRequest request) {
        OrderResponse response = doCreate(request);
        meterRegistry.counter("order.created",
            "status", "success",
            "payment_method", request.paymentMethod()
        ).increment();
        return response;
    }
}
```

## 3) Timer

```java
// 수동 측정
Timer.Sample sample = Timer.start(meterRegistry);
try {
    return externalApiClient.call();
} finally {
    sample.stop(meterRegistry.timer("external.api.duration",
        "endpoint", "/api/products"));
}

// 어노테이션 방식 (AspectJ 필요)
@Timed(value = "order.processing", description = "Order processing time")
public OrderResponse processOrder(OrderCreateRequest request) { ... }
```

## 4) Gauge

```java
// 현재 큐 사이즈 모니터링
Gauge.builder("batch.queue.size", queue, Queue::size)
    .description("Current batch queue size")
    .register(meterRegistry);
```

## 5) 태그 전략

- 태그 카디널리티(cardinality)를 낮게 유지 — `userId` 같은 고카디널리티 태그는 사용 금지
- 허용 태그 예: `status`, `method`, `endpoint`, `region`, `instance`
- 금지 태그: `userId`, `orderId`, `email` (개인 식별 정보 + 메트릭 폭증)

## 6) Prometheus 노출 확인

`application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: prometheus
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
```

`GET /actuator/prometheus` 에서 메트릭 확인.
