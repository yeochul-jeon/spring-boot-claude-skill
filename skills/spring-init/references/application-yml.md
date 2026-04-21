# application.yml 구조

환경별 프로파일 분리 + 민감정보 환경변수 참조를 기본으로 한다.

---

## 1) 파일 구성

```
src/main/resources/
├── application.yml          # 공통 설정 + 기본값
├── application-local.yml    # 로컬 개발
├── application-dev.yml      # 개발 서버
└── application-prod.yml     # 운영
```

프로파일 선택: `SPRING_PROFILES_ACTIVE=local ./gradlew bootRun`
기본 프로파일: `local` (개발자 실수 방지용).

---

## 2) `application.yml` (공통)

```yaml
spring:
  application:
    name: ${APP_NAME:order-api}
  profiles:
    default: local
  jackson:
    default-property-inclusion: non_null
    deserialization:
      fail-on-unknown-properties: true

server:
  port: ${SERVER_PORT:8080}
  error:
    include-message: never           # 프로덕션 기본: 메시지 노출 금지
    include-stacktrace: never
  forward-headers-strategy: framework

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      probes:
        enabled: true

logging:
  level:
    root: INFO
    com.example: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
```

---

## 3) `application-local.yml`

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/orderapi?serverTimezone=UTC
    username: ${DB_USERNAME:root}
    password: ${DB_PASSWORD:root}
  jpa:
    hibernate:
      ddl-auto: update          # 로컬만 update. dev/prod 는 validate
    show-sql: true
    properties:
      hibernate.format_sql: true

logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.orm.jdbc.bind: TRACE

server:
  error:
    include-message: always     # 로컬은 디버그 편의상 노출
    include-stacktrace: on_param
```

---

## 4) `application-dev.yml`

```yaml
spring:
  datasource:
    url: ${DB_URL}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus

logging:
  level:
    com.example: DEBUG
```

---

## 5) `application-prod.yml`

```yaml
spring:
  datasource:
    url: ${DB_URL:?DB_URL required}
    username: ${DB_USERNAME:?DB_USERNAME required}
    password: ${DB_PASSWORD:?DB_PASSWORD required}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false          # N+1 / LazyInitializationException 감시

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      show-details: when-authorized

logging:
  level:
    root: WARN
    com.example: INFO
```

---

## 6) 원칙

- **민감정보는 YAML 에 상수로 박지 않는다.** `${ENV_VAR}` 또는 `${ENV_VAR:?message}` 사용
- `ddl-auto: create`, `create-drop` 은 테스트/로컬 전용
- `spring.profiles.active` 를 코드·YAML 에 박지 않는다 (환경변수로만 결정)
- `application-secret.yml` 같은 비밀 프로파일은 `.gitignore` 에 포함
- `@ConfigurationProperties` 로 타입 안전 바인딩 권장 (문자열 키 산포 방지)

---

## 7) `.gitignore` 권장 추가

```
/.env
/.env.*
application-secret.yml
application-*-local-override.yml
```
