# 분산 추적 — OpenTelemetry / Micrometer Tracing

## 1) Spring Boot 3.x OTel 통합

```kotlin
dependencies {
    implementation("io.micrometer:micrometer-tracing-bridge-otel")
    implementation("io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter")
    // OTLP exporter
    implementation("io.opentelemetry:opentelemetry-exporter-otlp")
}
```

Spring Boot 3.x 는 Micrometer Tracing을 통해 OTel을 추상화한다. 특정 벤더 SDK 에 직접 의존하지 않는다.

## 2) 설정

```yaml
management:
  tracing:
    sampling:
      probability: 1.0   # 개발: 100% / 운영: 0.1 (10%) 이하 권장
  otlp:
    tracing:
      endpoint: http://otel-collector:4318/v1/traces
  zipkin:
    tracing:
      endpoint: http://zipkin:9411/api/v2/spans   # Zipkin 직접 연동 시
```

## 3) Trace / Span 컨텍스트 전파

HTTP 헤더로 Trace Context 자동 전파:
- W3C `traceparent` (기본, OTel 표준)
- B3 (Zipkin 호환)

Spring Boot 자동 설정으로 `@RestController`, `RestTemplate`, `WebClient` 호출 시 자동 주입됨.

## 4) 수동 Span 생성

```java
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final Tracer tracer;

    public PaymentResult processPayment(PaymentRequest request) {
        Span span = tracer.nextSpan().name("payment.process").start();
        try (Tracer.SpanInScope ws = tracer.withSpan(span)) {
            span.tag("payment.method", request.method());
            return doProcess(request);
        } catch (Exception e) {
            span.error(e);
            throw e;
        } finally {
            span.end();
        }
    }
}
```

## 5) 로그 + Trace 연결

`logback-spring.xml`에서 MDC의 `traceId`/`spanId` 를 로그에 포함:

```xml
<pattern>%d{HH:mm:ss} [%X{traceId},%X{spanId}] %-5level %logger{36} - %msg%n</pattern>
```

또는 Logstash encoder:

```xml
<encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <includeMdcKeyName>traceId</includeMdcKeyName>
    <includeMdcKeyName>spanId</includeMdcKeyName>
</encoder>
```

## 6) Sampling 전략

| 전략 | 설명 | 사용 시점 |
|------|------|-----------|
| `AlwaysOn` (1.0) | 전부 추적 | 개발/디버깅 |
| `TraceIdRatioBased` (0.1) | 10% 추적 | 운영 일반 트래픽 |
| `ParentBased` | 부모 Span 결정에 따름 | MSA 환경 |
| `RateLimiting` | 초당 N건 추적 | 트래픽 변동이 클 때 |
