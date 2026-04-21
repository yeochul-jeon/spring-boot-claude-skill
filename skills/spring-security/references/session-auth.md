# 세션 기반 인증 가이드

세션 기반 인증을 선택했을 때의 `SecurityFilterChain` 구성, 세션 고정 공격 방어,
세션 저장소 옵션을 다룬다.

---

## 1) SecurityFilterChain — 세션 기반

```java
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final UserDetailsService userDetailsService;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.ignoringRequestMatchers("/api/v1/auth/**"))  // REST는 CSRF 선택적 비활성화
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
                .sessionFixation().changeSessionId()          // 세션 고정 공격 방어
                .maximumSessions(1)                           // 동시 로그인 제한 (선택)
                .maxSessionsPreventsLogin(false)              // true: 신규 로그인 차단, false: 기존 세션 만료
            )
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/login", "/api/v1/auth/register").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .formLogin(form -> form
                .loginProcessingUrl("/api/v1/auth/login")
                .successHandler(authenticationSuccessHandler())
                .failureHandler(authenticationFailureHandler())
                .permitAll()
            )
            .logout(logout -> logout
                .logoutUrl("/api/v1/auth/logout")
                .invalidateHttpSession(true)
                .deleteCookies("JSESSIONID")
                .logoutSuccessHandler((req, res, auth) ->
                    res.setStatus(HttpServletResponse.SC_NO_CONTENT))
            );
        return http.build();
    }
}
```

---

## 2) UserDetailsService 구현

```java
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final MemberRepository memberRepository;

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        return memberRepository.findByEmail(email)
            .map(member -> User.builder()
                .username(member.getEmail())
                .password(member.getPassword())  // 이미 인코딩된 비밀번호
                .roles(member.getRole().name())
                .build())
            .orElseThrow(() -> new UsernameNotFoundException("User not found: " + email));
    }
}
```

---

## 3) 세션 고정 공격 방어

세션 고정 공격: 공격자가 미리 발급한 세션 ID를 피해자에게 주입해 로그인 후 탈취.

| 전략 | 동작 | 권장 |
|---|---|---|
| `changeSessionId()` | 로그인 성공 시 세션 ID 교체, 데이터 유지 | **기본값, 권장** |
| `newSession()` | 새 세션 생성, 이전 세션 데이터 초기화 | 세션 데이터 이전이 불필요할 때 |
| `none()` | 방어 없음 | 금지 |
| `migrateSession()` | 세션 데이터 복사 후 새 ID 발급 (구버전) | `changeSessionId`로 대체됨 |

---

## 4) 세션 저장소

**단일 서버**: 기본 `HttpSession` (메모리) 그대로 사용.

**수평 확장 (로드밸런서 2대+)**: Spring Session + Redis로 외부화.

```yaml
# application.yml
spring:
  session:
    store-type: redis
    timeout: 30m
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
```

```java
// @EnableRedisHttpSession 대신 자동 구성 활용 (Spring Boot)
// spring.session.store-type=redis 설정만으로 활성화
```

세션 직렬화: 기본 `JdkSerializationRedisSerializer`는 크기가 크다.
`GenericJackson2JsonRedisSerializer`로 교체하면 가독성과 크기 모두 개선.

```java
@Configuration
public class RedisConfig {

    @Bean
    public RedisSerializer<Object> springSessionDefaultRedisSerializer() {
        return new GenericJackson2JsonRedisSerializer();
    }
}
```

---

## 5) 로그인 성공/실패 핸들러 (REST API)

폼 로그인 리다이렉트 대신 JSON 응답을 반환할 때 커스텀 핸들러가 필요하다.

```java
@Bean
public AuthenticationSuccessHandler authenticationSuccessHandler() {
    return (request, response, authentication) -> {
        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write("{\"message\": \"로그인 성공\"}");
    };
}

@Bean
public AuthenticationFailureHandler authenticationFailureHandler() {
    return (request, response, exception) -> {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write("{\"message\": \"인증 실패\"}");
    };
}
```

---

## 6) 세션 타임아웃 설정

```yaml
server:
  servlet:
    session:
      timeout: 30m   # 기본 30분. 0이나 -1이면 무제한 (금지)
      cookie:
        http-only: true   # XSS 방어
        secure: true      # HTTPS only (운영 환경)
        same-site: strict # CSRF 방어 보조
```

---

## 요약 체크리스트

- [ ] `sessionFixation().changeSessionId()` 적용
- [ ] 로그아웃 시 `invalidateHttpSession(true)` + `deleteCookies("JSESSIONID")`
- [ ] 수평 확장 환경이면 Spring Session + Redis 구성
- [ ] 세션 쿠키 `httpOnly = true`, 운영 환경 `secure = true`
- [ ] 동시 로그인 제한이 필요하면 `maximumSessions` 설정
