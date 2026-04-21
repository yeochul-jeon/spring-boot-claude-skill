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

`@RestControllerAdvice` 하나를 프로젝트 전체에 등록하고 `ProblemDetail` 반환.  
도메인 예외 → HTTP 상태 매핑은 `references/exception-handling.md` 참조.

### 5. Validation

Bean Validation 어노테이션 카탈로그·커스텀 validator는 `references/validation.md` 참조.

### 6. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] Controller 메서드의 반환 타입이 DTO (`*Response` 또는 `ResponseEntity<*Response>`)
- [ ] `@RestControllerAdvice`가 등록되어 있고 `ProblemDetail` 반환
- [ ] 예외 → HTTP 상태 매핑이 `@RestControllerAdvice` 내에 문서화
- [ ] `@RequestBody` 파라미터에 `@Valid` 적용
- [ ] URL이 명사 복수 + kebab-case (`/members`, `/order-items`)
- [ ] `spring-principles` 체크리스트 전 항목 통과

## references/ 목록

| 파일 | 설명 |
|---|---|
| `rest-conventions.md` | URL 네이밍, HTTP 메서드 기준, 상태 코드 매핑표 |
| `dto-patterns.md` | Request/Response DTO 설계, record 활용, 매핑 전략 |
| `exception-handling.md` | `@RestControllerAdvice` + ProblemDetail 구조 |
| `validation.md` | Bean Validation 카탈로그, 커스텀 validator |
