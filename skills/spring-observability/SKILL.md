---
name: spring-observability
description: Use when adding observability to Spring Boot applications.
  Trigger on "모니터링", "메트릭", "Actuator", "Micrometer", "분산 추적",
  "tracing", "OpenTelemetry", "Prometheus", "structured logging", "로그 상관관계".
  Enforces minimal Actuator endpoint exposure, OTel tracing, structured JSON
  logging, and correlation ID propagation.
---

# Spring Observability

Spring Boot Observability(관찰 가능성) 계층의 표준 패턴.
Metrics → Tracing → Logging 세 축을 순서대로 구성하며,
코드 작성 완료 후 `spring-principles` 체크리스트로 자가 검증한다.

## 절대 원칙

1. **Actuator 엔드포인트는 최소한으로 노출한다.** 기본 전체 노출(`"*"`)은 정보 유출 위험 — 필요한 엔드포인트만 명시적으로 허용한다.
2. **구조화된 로그(JSON)를 사용한다.** 평문 로그는 로그 집계 시스템에서 파싱 비용이 크다.
3. **Correlation ID를 요청 전 구간에 전파한다.** 로그와 트레이스에 동일한 식별자가 있어야 분산 추적이 가능하다.
4. **Micrometer를 통해 메트릭을 추상화한다.** 특정 모니터링 시스템(Prometheus, Datadog 등)에 직접 의존하지 않는다.

## 워크플로우

### 1. 의존성 추가

```kotlin
dependencies {
    // Actuator + Micrometer
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    runtimeOnly("io.micrometer:micrometer-registry-prometheus")

    // OpenTelemetry Tracing (Spring Boot 3.x 기본 통합)
    implementation("io.micrometer:micrometer-tracing-bridge-otel")
    implementation("io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter")

    // Structured Logging
    implementation("net.logstash.logback:logstash-logback-encoder:${latestVersion}")
}
```

> logstash-logback-encoder 버전은 Maven Central에서 최신을 확인한다.

### 2. Actuator 노출 제한

`application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, prometheus, metrics
  endpoint:
    health:
      show-details: when-authorized
```

### 3. Micrometer 커스텀 메트릭

`references/metrics.md` 참조.

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final MeterRegistry meterRegistry;

    @Transactional
    public OrderResponse createOrder(OrderCreateRequest request) {
        OrderResponse response = doCreate(request);
        meterRegistry.counter("order.created", "status", "success").increment();
        return response;
    }
}
```

### 4. 분산 추적 설정

`references/tracing.md` 참조.

```yaml
management:
  tracing:
    sampling:
      probability: 1.0   # 개발: 1.0 / 운영: 0.1~0.3
  otlp:
    tracing:
      endpoint: http://otel-collector:4318/v1/traces
```

### 5. 구조화 로그 + Correlation ID

`references/logging.md` 참조.

`logback-spring.xml`:

```xml
<appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
        <includeMdcKeyName>traceId</includeMdcKeyName>
        <includeMdcKeyName>spanId</includeMdcKeyName>
        <includeMdcKeyName>correlationId</includeMdcKeyName>
    </encoder>
</appender>
```

Correlation ID 필터:

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorrelationIdFilter implements Filter {

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
        throws IOException, ServletException {
        String correlationId = Optional
            .ofNullable(((HttpServletRequest) req).getHeader("X-Correlation-ID"))
            .orElse(UUID.randomUUID().toString());
        MDC.put("correlationId", correlationId);
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.remove("correlationId");
        }
    }
}
```

### 6. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] Actuator 노출 엔드포인트가 `include` 명시 방식으로 최소화됨 (`"*"` 사용 금지)
- [ ] `/actuator/health` 세부 정보가 인증된 요청에만 노출됨
- [ ] Micrometer를 통해 커스텀 비즈니스 메트릭 등록 (직접 Prometheus API 사용 금지)
- [ ] OTel tracing 설정 완료 + sampling probability 명시
- [ ] Structured Logging (JSON) 적용 — 평문 로그 패턴 금지
- [ ] Correlation ID MDC 전파 필터 등록
- [ ] `spring-principles` 체크리스트 전 항목 통과

## grep 자동 검증 패턴

`<SRC>` 는 프로젝트의 `src/main/java` 절대 경로, `<RES>` 는 `src/main/resources`.

```bash
# O1: Actuator wildcard 노출 (0건이어야 PASS)
echo "=== [O1] Actuator wildcard 노출 ==="
grep -rn 'include.*"\*"\|include: "\*"' <RES>/ || echo "PASS"

# O2: @EnableCaching 아닌 MeterRegistry 직접 구현 확인 (수동)
echo "=== [O2] MeterRegistry 사용 ==="
grep -rn "MeterRegistry" <SRC>/ | grep -v "//\|import" | head -5

# O3: CorrelationId / MDC 전파 필터 존재 (1건 이상이어야 PASS)
echo "=== [O3] Correlation ID 필터 ==="
grep -rn "CorrelationId\|correlationId\|MDC.put" <SRC>/ | head -3
echo "(위 결과 1건 이상 → PASS)"

# O4: Structured logging encoder 설정 (1건 이상이어야 PASS)
echo "=== [O4] Structured logging ==="
grep -rn "LogstashEncoder\|logstash-logback\|StructuredLogging" <SRC>/../resources/ 2>/dev/null | head -3
echo "(위 결과 1건 이상 → PASS)"

# O5: tracing sampling 설정 (1건 이상이어야 PASS)
echo "=== [O5] Tracing sampling ==="
grep -rn "sampling.probability\|tracing" <RES>/ | head -3
echo "(위 결과 1건 이상 → PASS)"
```

## references/ 목록

| 파일 | 설명 |
|---|---|
| `metrics.md` | Micrometer Counter/Timer/Gauge/Summary, 커스텀 메트릭 등록, 태그 전략 |
| `tracing.md` | OTel tracing 설정, sampling 전략, 분산 추적 B3/W3C 헤더, Zipkin/Jaeger/OTLP |
| `logging.md` | Structured JSON logging, Correlation ID MDC 전파, logback 프로파일별 설정 |
