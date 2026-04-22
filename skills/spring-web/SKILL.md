---
name: spring-web
description: Use when building REST APIs with Spring Boot, including
  @RestController design, request/response DTOs, @RestControllerAdvice
  for exception handling, and Bean Validation. Trigger on "REST API",
  "controller 추가", "예외 처리", "DTO 설계". Always separates DTOs
  from entities and uses ProblemDetail (RFC 7807) for errors.
---

# Spring Web

Spring Boot REST API의 Controller·DTO·예외 처리·Validation 표준 패턴.
코드 작성 완료 후 반드시 `spring-principles` 체크리스트로 자가 검증한다.

## 절대 원칙

1. **Controller ↔ 외부는 오직 DTO.** Entity를 직접 반환하거나 `@RequestBody`로 수신하지 않는다.
2. **에러 응답은 `ProblemDetail`(RFC 7807)로 통일.** 애드혹 에러 JSON 객체 금지.
3. **모든 입력은 Bean Validation을 경유한다.** `@RequestBody`에 `@Valid`, Path/Query 파라미터에 `@Validated`.

## 워크플로우

### 1. 요청 흐름 설계

Controller → Service → Repository 계층 경계를 먼저 확인한다.  
계층 책임 기준은 `spring-principles/references/separation-of-concerns.md` 참조.

### 2. DTO 설계

- 입력: `*Request` record (`@Valid` 적용)
- 출력: `*Response` record (Entity 직접 노출 금지)
- 매핑: static factory 메서드 또는 MapStruct
- 상세: `references/dto-patterns.md` 참조

```java
// 입력 DTO
public record MemberRegisterRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8) String password
) {}

// 출력 DTO
public record MemberResponse(Long id, String email) {
    public static MemberResponse from(Member member) {
        return new MemberResponse(member.getId(), member.getEmail());
    }
}
```

### 3. Controller 작성

- URL: 명사 복수 + kebab-case (`/order-items`, `/members`)
- HTTP 메서드·상태 코드는 `references/rest-conventions.md` 매핑표 준수
- `ResponseEntity<T>` 로 상태 코드 명시

```java
@RestController
@RequestMapping("/api/v1/members")
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;

    @PostMapping
    public ResponseEntity<MemberResponse> register(
        @RequestBody @Valid MemberRegisterRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(memberService.register(request));
    }

    @GetMapping("/{id}")
    public MemberResponse findById(@PathVariable Long id) {
        return memberService.findById(id);
    }
}
```

### 4. 예외 처리

컨트롤러 내부 `@ExceptionHandler` **금지** — 모든 예외는 별도 `@RestControllerAdvice`로 분리.  
`ProblemDetail` 반환, 도메인 예외 → HTTP 상태 매핑은 `references/exception-handling.md` 참조.

### 5. Validation

Bean Validation 어노테이션 카탈로그·커스텀 validator는 `references/validation.md` 참조.

### 6. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] Controller 메서드의 반환 타입이 DTO (`*Response` 또는 `ResponseEntity<*Response>`)
- [ ] `@RequestBody`에 `Map<String, String>` 또는 raw 타입이 없다 — `*Request` record 사용
- [ ] `@RequestBody` 파라미터에 `@Valid` 적용
- [ ] `@RestControllerAdvice`가 등록되어 있고 `ProblemDetail` 반환
- [ ] Controller 내부에 `@ExceptionHandler` 없음 — `@RestControllerAdvice`로 분리
- [ ] 에드혹 에러 JSON (`Map<String, String>`) 없음 — `ProblemDetail`로 통일
- [ ] URL이 명사 복수 + kebab-case (`/members`, `/order-items`)
- [ ] `spring-principles` 체크리스트 전 항목 통과

## grep 자동 검증 패턴

체크리스트 실행 전 아래 명령으로 명백한 위반을 빠르게 탐지한다.
`<SRC>` 는 프로젝트의 `src/main/java` 절대 경로.

```bash
# W1: Controller가 Entity를 직접 반환하는지 (0건이어야 PASS)
grep -rn "public Member\|public Order\|public Product\|public User" <SRC>/*/controller/

# W2: @RestControllerAdvice 없음 (1건 이상이어야 PASS)
grep -rn "@RestControllerAdvice" <SRC>   # 0건이면 FAIL

# W3: Controller 내부 @ExceptionHandler (0건이어야 PASS)
grep -rn "@ExceptionHandler" <SRC>/*/controller/

# W4: ProblemDetail 미사용 — 에드혹 에러 Map (0건이어야 PASS)
grep -rn "Map<String.*String>.*error\|put.*\"error\"\|new HashMap" <SRC>/*/controller/

# W5a: @Valid 없는 @RequestBody (출력이 있으면 확인 필요)
grep -rn "@RequestBody" <SRC>/*/controller/ | grep -v "@Valid"

# W5b: @RequestBody에 Map 사용 (0건이어야 PASS)
grep -rn "@RequestBody Map<" <SRC>/*/controller/

# W6: URL 단수 또는 camelCase 패턴 확인 (수동 확인 병행)
grep -rn "@RequestMapping\|@PostMapping\|@GetMapping\|@PutMapping\|@DeleteMapping" <SRC>/*/controller/
```

결과가 있으면 `references/` 해당 파일의 Before→After 패턴을 적용한다.

## references/ 목록

| 파일 | 설명 |
|---|---|
| `rest-conventions.md` | URL 네이밍, HTTP 메서드 기준, 상태 코드 매핑표 |
| `dto-patterns.md` | Request/Response DTO 설계, record 활용, 매핑 전략 |
| `exception-handling.md` | `@RestControllerAdvice` + ProblemDetail 구조 |
| `validation.md` | Bean Validation 카탈로그, 커스텀 validator |
