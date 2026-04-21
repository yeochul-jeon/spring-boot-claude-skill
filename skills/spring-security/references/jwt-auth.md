# JWT 인증 가이드

JWT를 선택했을 때의 토큰 발급·검증 필터, Refresh Token 전략, 키 관리 표준.
`spring-principles/references/separation-of-concerns.md`의 계층 책임 원칙과 함께 적용한다.

---

## 1) SecurityFilterChain — JWT 기반

```java
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthFilter;
    private final UserDetailsService userDetailsService;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())           // JWT는 CSRF 불필요 (쿠키 미사용)
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))  // 세션 생성 금지
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config)
            throws Exception {
        return config.getAuthenticationManager();
    }
}
```

---

## 2) JWT 필터

```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider tokenProvider;
    private final UserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String token = extractToken(request);

        if (token != null && tokenProvider.validateToken(token)) {
            String email = tokenProvider.extractEmail(token);
            UserDetails userDetails = userDetailsService.loadUserByUsername(email);

            UsernamePasswordAuthenticationToken auth =
                new UsernamePasswordAuthenticationToken(
                    userDetails, null, userDetails.getAuthorities());
            auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

            SecurityContextHolder.getContext().setAuthentication(auth);
        }

        filterChain.doFilter(request, response);
    }

    private String extractToken(HttpServletRequest request) {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (StringUtils.hasText(header) && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }
}
```

---

## 3) JwtTokenProvider

```java
@Component
public class JwtTokenProvider {

    @Value("${jwt.secret}")           // 환경변수 주입 필수, 코드에 하드코딩 금지
    private String secretKey;

    @Value("${jwt.expiration-ms:900000}")        // 15분 기본
    private long accessTokenExpirationMs;

    @Value("${jwt.refresh-expiration-ms:604800000}")  // 7일 기본
    private long refreshTokenExpirationMs;

    private SecretKey getSigningKey() {
        byte[] keyBytes = Decoders.BASE64.decode(secretKey);
        return Keys.hmacShaKeyFor(keyBytes);
    }

    public String generateAccessToken(UserDetails userDetails) {
        return Jwts.builder()
            .subject(userDetails.getUsername())
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + accessTokenExpirationMs))
            .signWith(getSigningKey())
            .compact();
    }

    public String generateRefreshToken(UserDetails userDetails) {
        return Jwts.builder()
            .subject(userDetails.getUsername())
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + refreshTokenExpirationMs))
            .signWith(getSigningKey())
            .compact();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser().verifyWith(getSigningKey()).build().parseSignedClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public String extractEmail(String token) {
        return Jwts.parser()
            .verifyWith(getSigningKey())
            .build()
            .parseSignedClaims(token)
            .getPayload()
            .getSubject();
    }
}
```

---

## 4) 인증 엔드포인트

```java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<TokenResponse> login(@RequestBody @Valid LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/refresh")
    public ResponseEntity<TokenResponse> refresh(@RequestBody @Valid RefreshRequest request) {
        return ResponseEntity.ok(authService.refresh(request.refreshToken()));
    }
}

public record TokenResponse(String accessToken, String refreshToken, long expiresIn) {}
```

---

## 5) Refresh Token 전략

Refresh Token은 Access Token 만료 후 재발급에 사용한다.

**저장 위치**

| 옵션 | 장점 | 단점 |
|---|---|---|
| DB (Redis) | 즉시 무효화 가능 | 네트워크 I/O 추가 |
| HTTP-only 쿠키 | XSS 방어 | CSRF 고려 필요 |
| 클라이언트 로컬 | 단순 | 탈취 시 대응 어려움 |

**권장**: Redis에 `{userId → refreshToken}` 저장. 로그아웃 시 삭제 → 즉시 무효화.

```java
@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider tokenProvider;
    private final UserDetailsService userDetailsService;
    private final RefreshTokenRepository refreshTokenRepository;  // Redis or JPA

    public TokenResponse login(LoginRequest request) {
        Authentication auth = authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(request.email(), request.password()));

        UserDetails userDetails = (UserDetails) auth.getPrincipal();
        String accessToken = tokenProvider.generateAccessToken(userDetails);
        String refreshToken = tokenProvider.generateRefreshToken(userDetails);

        refreshTokenRepository.save(request.email(), refreshToken);  // Redis에 저장
        return new TokenResponse(accessToken, refreshToken, 900);
    }

    public TokenResponse refresh(String refreshToken) {
        if (!tokenProvider.validateToken(refreshToken)) {
            throw new InvalidTokenException("유효하지 않은 Refresh Token");
        }
        String email = tokenProvider.extractEmail(refreshToken);
        String stored = refreshTokenRepository.findByEmail(email)
            .orElseThrow(() -> new InvalidTokenException("만료되거나 로그아웃된 토큰"));

        if (!stored.equals(refreshToken)) {
            throw new InvalidTokenException("토큰 불일치");
        }

        UserDetails userDetails = userDetailsService.loadUserByUsername(email);
        return new TokenResponse(tokenProvider.generateAccessToken(userDetails), refreshToken, 900);
    }
}
```

---

## 6) 키 관리

**시크릿 키 생성 (HS256)**

```bash
# 256비트(32바이트) 이상 Base64 인코딩 키 생성
openssl rand -base64 32
```

**application.yml — 절대 하드코딩 금지**

```yaml
jwt:
  secret: ${JWT_SECRET}          # 환경변수에서 주입
  expiration-ms: 900000          # 15분
  refresh-expiration-ms: 604800000  # 7일
```

**비대칭 키 (RS256) — 더 강한 보안**

서비스 간 검증 시 공개 키 배포가 필요한 마이크로서비스 환경에 적합.

```yaml
jwt:
  private-key-path: ${JWT_PRIVATE_KEY_PATH}
  public-key-path: ${JWT_PUBLIC_KEY_PATH}
```

---

## 7) JWT 알려진 함정

| 함정 | 대응 |
|---|---|
| 토큰 즉시 무효화 불가 | Access Token 만료 시간을 짧게(15분), Refresh Token을 Redis에 저장 |
| `alg: none` 공격 | 라이브러리가 기본 방어. 직접 파싱 로직 작성 금지 |
| 클레임 정보 노출 | 페이로드는 Base64 인코딩이라 평문과 동일. 민감정보 넣지 않음 |
| 키 하드코딩 | 반드시 환경변수 또는 시크릿 매니저로 주입 |

---

## 요약 체크리스트

- [ ] `SessionCreationPolicy.STATELESS` 설정
- [ ] `jwtAuthFilter`를 `UsernamePasswordAuthenticationFilter` 앞에 등록
- [ ] JWT 시크릿 키가 환경변수(`${JWT_SECRET}`)로 주입, 코드에 하드코딩 없음
- [ ] Access Token 만료 시간 15분 이하
- [ ] Refresh Token Redis 저장, 로그아웃 시 삭제
- [ ] `validateToken` 예외 처리로 잘못된 토큰 필터 통과 차단
