# 회고 #8 재검증 가이드 — Security REST API

`plans/8-iterative-cherny.md` 에서 보강한 6개 영역이 스킬 문서만으로 자동 반영되는지
**새 Claude Code 세션**에서 확인한다.

> 선행 조건: `tests/manual-test-setup.md` 의 "스킬 인식 경로" 섹션을 먼저 숙지.

---

## 1. 테스트 디렉터리 준비

```bash
# spring-boot-claude-skill 의 부모 디렉터리에서
mkdir ../test-spring-security-v2 && cd ../test-spring-security-v2
```

현재 세션은 회고 작업 컨텍스트에 오염되어 있으므로 **반드시 별도 세션**을 기동한다.

```bash
claude
```

## 2. 스킬 연결

`tests/manual-test-setup.md` 의 권장 방식대로 프로젝트 로컬 `.claude/skills/`
심볼릭 링크를 건다.

```bash
mkdir -p .claude
ln -s ../../spring-boot-claude-skill/skills .claude/skills
```

## 3. 테스트 프롬프트

지난번(`../test-spring-security`)과 동일 조건으로 실행.

```
로그인 있는 REST API 프로젝트 만들어줘. Spring Boot 최신, MySQL, 세션 기반,
회원가입/로그인/로그아웃/내 정보 조회 + 통합 테스트까지.
```

## 4. 체크리스트

이번 회고에서 보강한 항목이 **사용자 개입 없이** 포함되는지 확인.

### 4.1 스킬/문서 트리거
- [ ] `spring-init` 이 먼저 invoke 됨
- [ ] `fetch-latest-versions.sh` 가 실행됨 (대화 로그에 스크립트 호출 흔적)
- [ ] `spring-security`, `spring-web`, `spring-testing` 이 순차 invoke 됨

### 4.2 Boot 버전 / 아티팩트
- [ ] `build.gradle.kts` 에 `3.x.x` · `4.x.x` 같은 구체 버전 숫자 하드코딩 **없음**
- [ ] SB 4.x 아티팩트 사용: `spring-boot-starter-webmvc`, `spring-boot-starter-webmvc-test`, `spring-boot-starter-security-test`
- [ ] 3.x 명칭(`spring-boot-starter-web`) 이 섞여 있지 않음

### 4.3 Security 설정
- [ ] `SecurityConfig` 에 다음 라인 포함:
  ```java
  .exceptionHandling(ex -> ex
      .authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
  ```
- [ ] `AuthenticationSuccessHandler` / `AuthenticationFailureHandler` 가 JSON 응답을 반환
- [ ] BCrypt / DelegatingPasswordEncoder 사용

### 4.4 예외 처리
- [ ] 컨트롤러 클래스 내부에 `@ExceptionHandler` 메서드 **없음**
- [ ] 별도 `@RestControllerAdvice` 클래스(`GlobalExceptionHandler` 등) 존재
- [ ] `ProblemDetail` 반환, `pd.setProperty("errors", ...)` 키 사용 (`fieldErrors` 아님)

### 4.5 application.yml
- [ ] CORS 기본값 패턴: `${ALLOWED_ORIGINS:http://localhost:3000,...}`
- [ ] 운영 프로파일은 `${VAR:?message}` 형식으로 강제
- [ ] 민감정보 상수 박제 없음

### 4.6 테스트 코드
- [ ] `@SpringBootTest` + `@AutoConfigureMockMvc` 기반 통합 테스트
- [ ] `SecurityMockMvcRequestBuilders.formLogin()` 사용
- [ ] `MockHttpSession` 으로 로그인 → `/me` → 로그아웃 → 401 흐름 검증
- [ ] `@BeforeEach` 에서 `repository.deleteAll()` 로 DB 격리
- [ ] ProblemDetail 검증: `jsonPath("$.title")`, `jsonPath("$.errors.<field>")`
- [ ] `./gradlew test` 전 테스트 통과

---

## 5. 실패 시 매핑표

항목이 빠졌다면 해당 스킬 문서의 트리거·링크가 부족한 것.

| 누락 항목 | 확인할 위치 |
|---|---|
| `HttpStatusEntryPoint` 없음 | `skills/spring-security/references/session-auth.md` §6 |
| 컨트롤러 내부 `@ExceptionHandler` 잔존 | `skills/spring-web/SKILL.md:81`, `exception-handling.md` 상단 원칙 |
| 3.x 아티팩트명 사용 | `skills/spring-init/references/gradle-conventions.md` SB 버전별 표 |
| CORS 기본값 누락 | `skills/spring-init/references/application-yml.md` §6 |
| `formLogin` / 세션 테스트 누락 | `skills/spring-testing/references/slice-tests.md` "Spring Security 통합 테스트" |
| ProblemDetail 키 불일치 | `slice-tests.md` 와 `exception-handling.md` 의 `errors` 키 일치 여부 |

통상 원인 두 가지:
1. SKILL.md `description` 트리거 키워드 부족 → 스킬이 invoke 되지 않음
2. 패턴이 `references/` 에만 있고 SKILL.md 워크플로우에 링크 안 됨 → 상세까지 도달하지 못함

해결 방향은 SKILL.md 워크플로우 단계에 **한 줄 링크 추가**가 최소 수정.

---

## 6. 결과 보고 템플릿

검증 세션 종료 후 이쪽 세션으로 다음을 공유:

```
## 생성 결과
- SecurityConfig.java: (핵심부 20줄 이내 발췌)
- GlobalExceptionHandler.java: (핵심부)
- build.gradle.kts dependencies 블록
- application.yml

## 테스트 결과
- 통과/실패 수
- 실패 시 로그

## 체크리스트 결과
- 통과: [...]
- 실패: [...] — 원인 추정
```

이후 매핑표 기반으로 추가 보강 계획을 수립한다.

---

## 7. 정리

검증이 끝나면 테스트 디렉터리를 삭제해도 된다.

```bash
cd ..
rm -rf test-spring-security-v2
```

동일 프롬프트를 다시 실행하면 스킬 변경 이력에 따른 회귀를 감지할 수 있으므로,
매 회고 후 `tests/regression-<번호>-*.md` 를 남겨 재현 가능하게 유지한다.
