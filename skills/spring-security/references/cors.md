# CORS 설정 가이드

Spring Security와 통합된 CORS 구성 방법. `CorsConfigurationSource` Bean을 사용하며
환경별(개발·운영) 원본 허용 정책을 분리하는 표준 패턴.

---

## 1) 왜 CorsConfigurationSource인가

Spring Security 필터 체인이 `DispatcherServlet`보다 앞에서 동작하므로
`WebMvcConfigurer.addCorsMappings`는 Security가 먼저 요청을 차단할 경우 적용되지 않는다.

`SecurityFilterChain`에 `.cors(cors -> cors.configurationSource(...))`로 등록하면
Preflight `OPTIONS` 요청이 Security 필터를 통과할 수 있다.

```java
// 권장
http.cors(cors -> cors.configurationSource(corsConfigurationSource()));

// 주의: WebMvcConfigurer만 사용하면 Security 레이어에서 막힐 수 있음
```

---

## 2) CorsConfigurationSource Bean

```java
@Configuration
public class SecurityConfig {

    @Value("${app.cors.allowed-origins}")
    private List<String> allowedOrigins;

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(allowedOrigins);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setExposedHeaders(List.of("Authorization", "Content-Disposition"));
        config.setAllowCredentials(true);   // 쿠키·세션 허용 시 true, JWT Bearer만이면 false 가능
        config.setMaxAge(3600L);            // Preflight 캐시 1시간

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
```

---

## 3) 환경별 원본 설정

`allowedOrigins`를 코드에 하드코딩하지 않는다. 환경변수 또는 프로파일별 설정으로 주입.

```yaml
# application-local.yml (개발)
app:
  cors:
    allowed-origins:
      - http://localhost:3000
      - http://localhost:5173  # Vite 기본 포트

# application-prod.yml (운영)
app:
  cors:
    allowed-origins:
      - https://www.example.com
      - https://admin.example.com
```

```yaml
# application.yml (기본값 — 운영 사고 방지용으로 비워두거나 엄격하게)
app:
  cors:
    allowed-origins: ${ALLOWED_ORIGINS}  # 환경변수 필수
```

---

## 4) allowCredentials 사용 시 주의

`allowCredentials = true`를 설정하면 `allowedOrigins`에 와일드카드(`*`)를 사용할 수 없다.

```java
// 오류: credentials + 와일드카드 조합
config.setAllowedOrigins(List.of("*"));  // ❌
config.setAllowCredentials(true);

// 올바른 방법: 도메인 명시
config.setAllowedOrigins(List.of("https://example.com"));  // ✅
config.setAllowCredentials(true);
```

**allowCredentials 필요 여부**

| 인증 방식 | `allowCredentials` |
|---|---|
| JWT (Authorization 헤더) | `false` 가능 (쿠키 불필요) |
| 세션 (JSESSIONID 쿠키) | `true` 필수 |
| JWT (HttpOnly 쿠키) | `true` 필수 |

---

## 5) 엔드포인트별 CORS 규칙 분리

공개 API와 인증 필요 API에 다른 CORS 규칙을 적용할 때:

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();

    // 공개 API: 더 넓은 허용
    CorsConfiguration publicConfig = new CorsConfiguration();
    publicConfig.setAllowedOrigins(List.of("*"));
    publicConfig.setAllowedMethods(List.of("GET"));
    source.registerCorsConfiguration("/api/v1/public/**", publicConfig);

    // 인증 API: 특정 도메인만
    CorsConfiguration privateConfig = new CorsConfiguration();
    privateConfig.setAllowedOrigins(allowedOrigins);
    privateConfig.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    privateConfig.setAllowedHeaders(List.of("*"));
    privateConfig.setAllowCredentials(true);
    source.registerCorsConfiguration("/api/v1/**", privateConfig);

    return source;
}
```

---

## 6) 안티패턴

```java
// 금지: 운영 환경에서 와일드카드
config.setAllowedOrigins(List.of("*"));  // 모든 도메인 허용

// 금지: @CrossOrigin을 Controller에 직접 선언 (Security 필터 우선 처리 누락 가능)
@CrossOrigin(origins = "*")
@RestController
public class MemberController { ... }

// 금지: allowedOrigins를 코드에 하드코딩
config.setAllowedOrigins(List.of("https://my-app.com"));
```

---

## 요약 체크리스트

- [ ] `SecurityFilterChain`에 `.cors(cors -> cors.configurationSource(...))` 연결
- [ ] `allowedOrigins`가 환경변수·프로파일 설정으로 주입 (하드코딩 없음)
- [ ] 운영 환경에 와일드카드(`*`) 사용 없음
- [ ] `allowCredentials = true` 시 구체적 도메인 명시
- [ ] Preflight `OPTIONS` 요청이 `permitAll()`로 통과되는지 확인
- [ ] 개발(`local`) 프로파일에 `localhost:3000` 등 로컬 프론트 주소 포함
