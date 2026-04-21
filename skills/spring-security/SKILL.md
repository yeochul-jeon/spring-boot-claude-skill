---
name: spring-security
description: Use when configuring authentication and authorization in
  Spring Boot. Trigger on "로그인", "인증", "권한", "JWT", "세션". The skill
  asks session-based vs JWT first, then configures SecurityFilterChain,
  password encoding, and CORS appropriately.
---

# Spring Security

Spring Boot 인증·인가 계층의 표준 패턴.
세션 기반 vs JWT를 먼저 결정하고, SecurityFilterChain · 비밀번호 인코더 · CORS를
순서대로 확정한 뒤 `spring-principles` 체크리스트로 자가 검증한다.

## 절대 원칙

1. **인증 방식을 가정하지 않는다.** `references/selection-guide.md` 체크리스트로 먼저 결정하고 사용자 승인을 받는다.
2. **비밀번호는 `DelegatingPasswordEncoder` 기본.** 알고리즘은 BCrypt, 평문 저장 금지.
3. **CORS는 반드시 명시.** `WebMvcConfigurer.addCorsMappings` 대신 `CorsConfigurationSource` Bean으로 등록한다.
4. **`WebSecurityConfigurerAdapter`는 사용하지 않는다.** `SecurityFilterChain` Bean으로 구성한다 (Spring Boot 3.x 기본 방식).

## 워크플로우

### 1. 인증 방식 선택

`references/selection-guide.md` 체크리스트로 세션 vs JWT 추천.
프롬프트에 이미 명시된 경우("JWT 써줘", "세션으로 해줘") 인터뷰 생략.
불명확하면 분석 결과 + 추천을 제시하고 사용자 확인.

### 2. 의존성 추가

`build.gradle.kts`에 추가:

**공통**

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-security")
    testImplementation("org.springframework.security:spring-security-test")
}
```

**JWT 경로 추가**

```kotlin
dependencies {
    implementation("io.jsonwebtoken:jjwt-api:${latestVersion}")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:${latestVersion}")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:${latestVersion}")
}
```

> JJWT 버전은 Maven Central에서 최신을 확인한다. 버전을 기억에 의존해 쓰지 않는다.

**세션 + 외부 저장소(선택)**

```kotlin
dependencies {
    implementation("org.springframework.session:spring-session-data-redis")
    implementation("org.springframework.boot:spring-boot-starter-data-redis")
}
```

### 3. SecurityFilterChain 구성

`references/session-auth.md` 또는 `references/jwt-auth.md` 패턴 적용.

**공통 뼈대**

```java
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .anyRequest().authenticated()
            );

        // 세션 경로: session-auth.md 참조
        // JWT 경로: jwt-auth.md 참조
        return http.build();
    }
}
```

### 4. 비밀번호 인코더 설정

`references/password-encoding.md` 참조.

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return PasswordEncoderFactories.createDelegatingPasswordEncoder();  // BCrypt 기본
}
```

### 5. CORS 설정

`references/cors.md` 패턴 적용.

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("${app.cors.allowed-origins}"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("*"));
    config.setAllowCredentials(true);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

### 6. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] 세션 vs JWT 선택을 사용자에게 확인했는가
- [ ] `DelegatingPasswordEncoder` (BCrypt 기본) 적용, 평문 저장 없음
- [ ] `CorsConfigurationSource` Bean 등록, `allowedOrigins`가 환경변수·설정값으로 주입
- [ ] JWT 선택 시: `SessionCreationPolicy.STATELESS`, JWT 필터 `addFilterBefore` 등록
- [ ] 세션 선택 시: 세션 고정 공격 방어 (`sessionFixation().changeSessionId()`)
- [ ] 공개 엔드포인트 (`/api/v1/auth/**`) `permitAll()` 명시
- [ ] CSRF: JWT는 disable, 세션은 운영 요구에 따라 활성화
- [ ] `spring-security-test` 의존성 포함
- [ ] `spring-principles` 체크리스트 전 항목 통과

## references/ 목록

| 파일 | 설명 |
|---|---|
| `selection-guide.md` | 세션 vs JWT 의사결정 체크리스트 (진입 시 첫 참조) |
| `session-auth.md` | Spring Session, 세션 고정 공격 방어, 세션 저장소 |
| `jwt-auth.md` | JWT 발급·검증 필터, Refresh Token, 키 관리 |
| `password-encoding.md` | BCrypt/Argon2 선택, DelegatingPasswordEncoder |
| `cors.md` | CorsConfigurationSource, 프런트 도메인 허용 정책 |
