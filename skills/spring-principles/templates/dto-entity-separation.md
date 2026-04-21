# DTO-Entity 분리 변환

## Before

```java
// Controller가 Entity를 직접 반환
@RestController
@RequiredArgsConstructor
public class MemberController {

    private final MemberRepository memberRepository;  // Repository 직접 주입

    @GetMapping("/members/{id}")
    public Member getMember(@PathVariable Long id) {   // Entity 반환
        return memberRepository.findById(id).orElseThrow();
    }

    @PostMapping("/members")
    public Member register(@RequestBody Member member) {  // Entity 수신
        return memberRepository.save(member);
    }
}
```

## After

```java
// Request DTO
public record MemberRegisterRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8) String password
) {}

// Response DTO
public record MemberResponse(Long id, String email) {
    public static MemberResponse from(Member member) {
        return new MemberResponse(member.getId(), member.getEmail().value());
    }
}

// Controller — Service만 주입, DTO만 노출
@RestController
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;

    @GetMapping("/members/{id}")
    public MemberResponse getMember(@PathVariable Long id) {
        return memberService.findById(id);
    }

    @PostMapping("/members")
    public ResponseEntity<MemberResponse> register(
        @RequestBody @Valid MemberRegisterRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(memberService.register(request));
    }
}
```

## 왜

Entity를 직접 반환하면 API 계약이 DB 스키마에 종속되어 컬럼 변경이 곧 API 변경이 된다. 또한 양방향 연관관계가 있는 Entity는 JSON 직렬화 시 무한 루프를 일으키며, 이를 `@JsonIgnore`로 막는 것은 도메인 모델이 표현 계층을 알게 만드는 설계 오염이다.

## 관련 원칙

- [references/separation-of-concerns.md](../references/separation-of-concerns.md)
- [references/anti-patterns.md](../references/anti-patterns.md)
