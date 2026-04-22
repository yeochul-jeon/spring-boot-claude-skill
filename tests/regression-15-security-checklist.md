# Regression Test #15 — spring-security 체크리스트 empirical 검증

날짜 초안: 2026-04-22

---

## 목적

`spring-security` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro17/auth-api
SRC=$SANDBOX/src/main/java
```

---

## §2 grep 자동 검증

```bash
# S1: WebSecurityConfigurerAdapter 사용 금지 (0건이어야 PASS)
echo "=== [S1] WebSecurityConfigurerAdapter ===" && grep -rn "WebSecurityConfigurerAdapter" $SRC/ || echo "PASS"

# S2: 평문 저장 / NoOp 인코더 금지 (0건이어야 PASS)
echo "=== [S2] NoOpPasswordEncoder ===" && grep -rn "NoOpPasswordEncoder" $SRC/ || echo "PASS"

# S3: DelegatingPasswordEncoder 사용 확인 (1건 이상이어야 PASS)
echo "=== [S3] DelegatingPasswordEncoder ===" && grep -rn "DelegatingPasswordEncoder\|PasswordEncoderFactories" $SRC/ || echo "FAIL: DelegatingPasswordEncoder 미사용"

# S4: 세션 고정 공격 방어 (세션 경로라면 1건 이상이어야 PASS)
echo "=== [S4] sessionFixation ===" && grep -rn "sessionFixation\|changeSessionId" $SRC/ || echo "FAIL: 세션 고정 방어 없음"

# S5: CorsConfigurationSource Bean 등록 (1건 이상이어야 PASS)
echo "=== [S5] CorsConfigurationSource ===" && grep -rn "CorsConfigurationSource" $SRC/ || echo "FAIL: CorsConfigurationSource 없음"

# S6: WebMvcConfigurer.addCorsMappings 사용 금지 (0건이어야 PASS)
echo "=== [S6] addCorsMappings ===" && grep -rn "addCorsMappings" $SRC/ || echo "PASS"

# S7: HttpStatusEntryPoint (REST API라면 1건 이상이어야 PASS)
echo "=== [S7] HttpStatusEntryPoint ===" && grep -rn "HttpStatusEntryPoint" $SRC/ || echo "FAIL: 302→401 미적용"

# S8: wildcard origin + credentials 조합 금지 (0건이어야 PASS)
echo "=== [S8] wildcard CORS ===" && grep -rn 'allowedOrigins.*"\*"' $SRC/ || echo "PASS"

# W2: @RestControllerAdvice 존재 확인 (1건 이상이어야 PASS)
echo "=== [W2] @RestControllerAdvice ===" && grep -rn "@RestControllerAdvice" $SRC/ || echo "FAIL: @RestControllerAdvice 없음"

# W_login: @RequestBody에 Map 사용 금지 (0건이어야 PASS)
echo "=== [W_login] @RequestBody Map ===" && grep -rn "@RequestBody.*Map" $SRC/com/example/authapi/controller/ || echo "PASS"
```

---

## §3 수동 체크리스트

```
인증 방식 선택
- [ ] 세션 vs JWT 선택을 사용자에게 확인했는가

비밀번호 인코딩
- [ ] DelegatingPasswordEncoder (BCrypt 기본) 적용, 평문 저장 없음
- [ ] new BCryptPasswordEncoder() 직접 사용 없음 (PasswordEncoderFactories 사용)

CORS
- [ ] CorsConfigurationSource Bean 등록
- [ ] allowedOrigins가 환경변수·설정값으로 주입 (하드코딩 없음)
- [ ] WebMvcConfigurer.addCorsMappings 사용 없음

세션 경로
- [ ] 세션 고정 공격 방어 (sessionFixation().changeSessionId())
- [ ] HttpStatusEntryPoint(UNAUTHORIZED) 등록 (미인증 접근 302→401)
- [ ] CSRF: 세션은 운영 요구에 따라 활성화

JWT 경로
- [ ] SessionCreationPolicy.STATELESS
- [ ] JWT 필터 addFilterBefore 등록

공통
- [ ] 공개 엔드포인트 /api/v1/auth/** permitAll() 명시
- [ ] spring-security-test 의존성 포함

spring-web 교차
- [ ] @RestControllerAdvice 등록 + ProblemDetail 반환
- [ ] @RequestBody에 @Valid 적용
- [ ] login 엔드포인트 @RequestBody에 LoginRequest record 사용 (Map 금지)
- [ ] Controller 내부 @ExceptionHandler 없음

spring-principles
- [ ] spring-principles 체크리스트 전 항목 통과
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-22 | 전체 (세션 기반 로그인 REST API) | FAIL (결함 5건) | 초기 baseline — retro #17 결함 수집 용도 |

### 2026-04-22 결함 목록

security-domain 결함 (3건):
- 결함 S3/S_DP: `new BCryptPasswordEncoder()` 직접 사용 — `DelegatingPasswordEncoder` 아님 → SKILL.md 항목 존재, grep `DelegatingPasswordEncoder` 패턴 추가
- 결함 S4: `sessionFixation().changeSessionId()` 없음 — 세션 고정 공격 방어 누락 → SKILL.md 항목 존재, grep 자동화 추가
- 결함 S5: `CorsConfigurationSource` Bean 없음 — CORS 미설정 → SKILL.md 항목 존재, grep 자동화 추가

spring-web 교차 결함 (2건):
- W2: `@RestControllerAdvice` 없음
- W_login: `@RequestBody Map<String, String>` 사용 (`LoginRequest` record 아님) + `@Valid` 미적용

> security-domain 3건은 SKILL.md 항목 존재, grep 자동화 부재 → grep 섹션 추가로 탐지 수단 강화.
> W2·W_login은 spring-web 영역 — spring-security SKILL이 `spring-web` 체크리스트 실행을 명시하지 않아 탐지 누락 → "spring-web 체크리스트 전 항목 통과" 항목 추가.
