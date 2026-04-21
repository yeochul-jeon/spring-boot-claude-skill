# 예외 처리 — @RestControllerAdvice + ProblemDetail

> **원칙**: 모든 예외 매핑은 `@RestControllerAdvice` 한 곳에 모은다.
> 컨트롤러 클래스 내부에 `@ExceptionHandler` 메서드를 두는 것은 **안티패턴** — 중복 발생, 일관성 깨짐, 테스트 어려움.
> `spring-principles/references/anti-patterns.md` 참조.

## 1) 기본 구조

프로젝트 전체에 `@RestControllerAdvice` 하나를 등록한다.  
에러 응답은 반드시 `ProblemDetail`(RFC 7807, Spring 6+/Boot 3+) 로 반환한다.

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    // Bean Validation 실패 (@Valid, @Validated)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail pd = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        pd.setTitle("Validation Failed");
        pd.setDetail("입력값 검증 오류");
        // 필드별 오류 목록을 확장 속성으로 추가
        Map<String, String> fieldErrors = ex.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.toMap(
                FieldError::getField,
                fe -> Objects.requireNonNullElse(fe.getDefaultMessage(), "invalid"),
                (a, b) -> a
            ));
        pd.setProperty("errors", fieldErrors);
        return pd;
    }

    // 도메인 예외: 리소스 없음
    @ExceptionHandler(EntityNotFoundException.class)
    public ProblemDetail handleNotFound(EntityNotFoundException ex) {
        ProblemDetail pd = ProblemDetail.forStatus(HttpStatus.NOT_FOUND);
        pd.setTitle("Not Found");
        pd.setDetail(ex.getMessage());
        return pd;
    }

    // 도메인 예외: 비즈니스 규칙 위반
    @ExceptionHandler(BusinessRuleViolationException.class)
    public ProblemDetail handleBusinessRule(BusinessRuleViolationException ex) {
        ProblemDetail pd = ProblemDetail.forStatus(HttpStatus.UNPROCESSABLE_ENTITY);
        pd.setTitle("Business Rule Violation");
        pd.setDetail(ex.getMessage());
        return pd;
    }

    // 도메인 예외: 중복·충돌
    @ExceptionHandler(DuplicateResourceException.class)
    public ProblemDetail handleConflict(DuplicateResourceException ex) {
        ProblemDetail pd = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        pd.setTitle("Conflict");
        pd.setDetail(ex.getMessage());
        return pd;
    }

    // 예측 못한 예외 — 내부 상세 노출 금지
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        ProblemDetail pd = ProblemDetail.forStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        pd.setTitle("Internal Server Error");
        pd.setDetail("서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.");
        // ex.getMessage() 노출 금지 — 내부 정보 누출
        return pd;
    }
}
```

## 2) ProblemDetail (RFC 7807) 필드

| 필드 | 타입 | 설명 |
|---|---|---|
| `type` | URI | 오류 유형 URI (없으면 `about:blank`) |
| `title` | String | 사람이 읽을 수 있는 짧은 제목 |
| `status` | int | HTTP 상태 코드 |
| `detail` | String | 이 발생의 구체적 설명 |
| `instance` | URI | 오류 발생 URI (보통 요청 경로) |
| 확장 속성 | any | `setProperty(key, value)`로 추가 |

```json
{
  "type": "about:blank",
  "title": "Validation Failed",
  "status": 400,
  "detail": "입력값 검증 오류",
  "instance": "/api/v1/members",
  "errors": {
    "email": "이메일 형식이 올바르지 않습니다",
    "password": "비밀번호는 8자 이상이어야 합니다"
  }
}
```

## 3) 도메인 예외 → HTTP 상태 매핑표

| 예외 클래스 | HTTP 상태 | 설명 |
|---|---|---|
| `EntityNotFoundException` | 404 | 요청 리소스 없음 |
| `DuplicateResourceException` | 409 | 이미 존재 (이메일 중복 등) |
| `BusinessRuleViolationException` | 422 | 도메인 규칙 위반 |
| `IllegalArgumentException` | 400 | 잘못된 인자 |
| `MethodArgumentNotValidException` | 400 | Bean Validation 실패 |
| `AccessDeniedException` | 403 | Spring Security 권한 거부 |
| `AuthenticationException` | 401 | 인증 실패 |
| `Exception` (기타) | 500 | 서버 오류 |

## 4) 커스텀 도메인 예외 기반 클래스 예시

```java
// 기반 예외
public abstract class DomainException extends RuntimeException {
    protected DomainException(String message) { super(message); }
}

// 구체 예외
public class EntityNotFoundException extends DomainException {
    public EntityNotFoundException(String entity, Object id) {
        super(entity + " not found: " + id);
    }
}

public class DuplicateResourceException extends DomainException {
    public DuplicateResourceException(String message) { super(message); }
}

public class BusinessRuleViolationException extends DomainException {
    public BusinessRuleViolationException(String message) { super(message); }
}
```

## 5) ProblemDetail 활성화 (application.yml)

Spring Boot 3+에서 기본 활성화. 명시적 설정:

```yaml
spring:
  mvc:
    problemdetails:
      enabled: true
```

## 관련 원칙

- [rest-conventions.md](./rest-conventions.md) — 상태 코드 매핑표
- [spring-principles/references/separation-of-concerns.md](../../spring-principles/references/separation-of-concerns.md)
