# Structured Logging + Correlation ID

## 1) Logstash Logback Encoder 설정

`build.gradle.kts`:

```kotlin
implementation("net.logstash.logback:logstash-logback-encoder:${latestVersion}")
```

`src/main/resources/logback-spring.xml`:

```xml
<configuration>
    <springProfile name="!local">
        <!-- 운영/스테이징: JSON -->
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeMdcKeyName>traceId</includeMdcKeyName>
                <includeMdcKeyName>spanId</includeMdcKeyName>
                <includeMdcKeyName>correlationId</includeMdcKeyName>
                <includeMdcKeyName>userId</includeMdcKeyName>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="JSON"/>
        </root>
    </springProfile>

    <springProfile name="local">
        <!-- 로컬 개발: 평문 -->
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss} [%X{traceId}] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="DEBUG">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>
</configuration>
```

## 2) Correlation ID 전파 필터

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorrelationIdFilter implements Filter {

    private static final String HEADER = "X-Correlation-ID";
    private static final String MDC_KEY = "correlationId";

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
        throws IOException, ServletException {
        HttpServletRequest httpReq = (HttpServletRequest) req;
        String correlationId = Optional.ofNullable(httpReq.getHeader(HEADER))
            .filter(id -> !id.isBlank())
            .orElse(UUID.randomUUID().toString());

        MDC.put(MDC_KEY, correlationId);
        ((HttpServletResponse) res).setHeader(HEADER, correlationId);
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }
}
```

## 3) 로그 레벨 전략

| 레벨 | 사용 기준 |
|------|----------|
| `ERROR` | 복구 불가한 오류, 즉시 알림 대상 |
| `WARN` | 복구 가능하나 주의 필요 (재시도, degraded state) |
| `INFO` | 주요 비즈니스 이벤트 (주문 생성, 결제 완료) |
| `DEBUG` | 개발 단계 디버깅 정보 (운영에서는 비활성) |

## 4) 로그에 포함할 컨텍스트 필드

```java
log.info("order created",
    kv("orderId", order.getId()),
    kv("memberId", member.getId()),
    kv("amount", order.getTotalAmount())
);
```

> Logstash encoder의 `net.logstash.logback.argument.StructuredArguments.kv()` 사용.

**개인 식별 정보(PII)는 로그에 포함하지 않는다** — 이메일, 전화번호, 비밀번호 금지.

## 5) Log Aggregation 연동

| 스택 | 설명 |
|------|------|
| EFK (Elasticsearch + Fluentd + Kibana) | 자가 호스팅, JSON 파싱 자동 |
| Loki + Grafana | 경량, Kubernetes 친화 |
| Datadog / New Relic | 관리형 SaaS |

JSON 로그 구조가 통일되면 어느 스택에서도 파싱 없이 바로 검색 가능.
