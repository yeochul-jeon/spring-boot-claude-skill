# 관심사 분리

## 1) 계층별 책임

| 계층 | 책임 | 금지 |
|---|---|---|
| **Controller** | HTTP 요청 수신, DTO 변환, 응답 반환 | Entity 직접 노출, 비즈니스 로직, Repository 직접 호출 |
| **Service** | 유스케이스 오케스트레이션, 트랜잭션 경계 | HTTP 개념(`HttpServletRequest` 등), 표현 로직 |
| **Repository** | 영속성 추상화 (CRUD, 쿼리) | 비즈니스 로직, 트랜잭션 시작 |

```
HTTP 요청
   ↓
Controller  (DTO ↔ HTTP)
   ↓
Service     (@Transactional, 유스케이스)
   ↓
Repository  (DB 접근)
   ↓
Entity      (도메인 상태 + 행위)
```

## 2) `@Transactional` 경계

- **Service 계층에만** `@Transactional` 을 선언한다.
- 조회 전용 메서드: `@Transactional(readOnly = true)` — Connection Pool flush 생략, 성능 향상.
- Repository에 `@Transactional`을 붙이지 않는다 (Spring Data가 내부적으로 관리하는 것과 별개).

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)   // 클래스 기본: 조회
public class MemberService {

    private final MemberRepository memberRepository;

    @Transactional                // 쓰기 메서드만 오버라이드
    public MemberResponse register(MemberRegisterRequest request) {
        Member member = Member.create(request.email(), request.password());
        return MemberResponse.from(memberRepository.save(member));
    }

    public MemberResponse findById(Long id) {   // readOnly 상속
        return MemberResponse.from(
            memberRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Member", id))
        );
    }
}
```

## 3) DTO 분리 원칙

- `*Request` — Controller 입력용. `@Valid` 적용.
- `*Response` — Controller 출력용. Entity를 감싼 뷰.
- Entity는 Controller/View 계층에 **절대 노출하지 않는다**.

```java
// Controller
@PostMapping("/members")
public ResponseEntity<MemberResponse> register(
    @RequestBody @Valid MemberRegisterRequest request
) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(memberService.register(request));
}
```

## 관련 원칙

- [di.md](./di.md) — 생성자 주입으로 계층 간 의존성 명확화
- [anti-patterns.md](./anti-patterns.md) — Controller→Repository 직통 호출 금지
