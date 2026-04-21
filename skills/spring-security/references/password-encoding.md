# 비밀번호 인코딩 가이드

비밀번호를 안전하게 저장하는 알고리즘 선택, `DelegatingPasswordEncoder` 구성,
마이그레이션 전략을 다룬다.

---

## 1) 기본 원칙

**절대 금지**

```java
// 금지: 평문 저장
member.setPassword(request.password());

// 금지: MD5, SHA-1 (단방향이지만 취약)
member.setPassword(DigestUtils.md5DigestAsHex(request.password().getBytes()));
```

**권장**

```java
// 권장: PasswordEncoder로 단방향 해싱
member.setPassword(passwordEncoder.encode(request.password()));
```

---

## 2) DelegatingPasswordEncoder (기본 설정)

`PasswordEncoderFactories.createDelegatingPasswordEncoder()`는 `{id}encodedPassword`
형식으로 저장해 알고리즘 교체를 코드 변경 없이 지원한다.

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return PasswordEncoderFactories.createDelegatingPasswordEncoder();  // BCrypt 기본
}
```

저장 예시:

```
{bcrypt}$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy
{argon2}$argon2id$v=19$m=16384,t=2,p=1$abc123...
```

접두사가 없으면 `UnmappedIdPasswordEncoder`로 처리되어 예외 발생 → 신규 코드에서는
반드시 `DelegatingPasswordEncoder`를 통해 저장.

---

## 3) 알고리즘 비교

| 알고리즘 | 권장도 | 메모리 하드 | 속도 조절 | 비고 |
|---|---|---|---|---|
| **BCrypt** | ✅ 기본 | ❌ | `strength` (10~12) | 오래되고 검증됨 |
| **Argon2id** | ✅ 더 강함 | ✅ | `memory`, `iterations` | OWASP 1순위 권장 |
| **SCrypt** | △ | ✅ | `CPU/메모리 조합` | 설정 복잡 |
| SHA-256/MD5 | ❌ 금지 | ❌ | 없음 | Rainbow table 취약 |

**BCrypt**: 기본 strength 10 권장. 12로 올리면 약 4배 느려짐.
**Argon2**: 더 강하지만 Spring Security 라이브러리에 보라이런 라이브러리 추가 필요.

```java
// BCrypt 강도 명시
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);  // strength 12
}

// 또는 Argon2 (더 강한 보안)
@Bean
public PasswordEncoder passwordEncoder() {
    return new Argon2PasswordEncoder(16, 32, 1, 16384, 2);
}
```

---

## 4) 비밀번호 검증 패턴

```java
@Service
@RequiredArgsConstructor
public class AuthService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;

    public void verifyPassword(String rawPassword, String encodedPassword) {
        if (!passwordEncoder.matches(rawPassword, encodedPassword)) {
            throw new BadCredentialsException("비밀번호가 일치하지 않습니다");
        }
    }
}
```

**주의**: `passwordEncoder.matches(raw, encoded)`는 타이밍 공격을 방어하는 constant-time 비교를 사용한다.
직접 `equals`로 비교하지 않는다.

---

## 5) 마이그레이션 전략

기존 MD5/SHA 해시를 BCrypt로 교체할 때:

**방법 1: 로그인 시 점진적 마이그레이션**

```java
public UserDetails loadUserByUsername(String email) {
    Member member = memberRepository.findByEmail(email)
        .orElseThrow(() -> new UsernameNotFoundException(email));

    // 구버전 해시 접두사 없음 → 로그인 성공 시 재인코딩
    if (!member.getPassword().startsWith("{")) {
        // 로그인 성공 후 새 비밀번호로 업데이트 (AuthenticationSuccessHandler에서 처리)
    }
    return ...;
}
```

**방법 2: 일괄 무효화 + 비밀번호 재설정 안내**

대규모 DB라면 점진적 마이그레이션보다 명시적 재설정 안내가 더 안전하다.

---

## 6) 비밀번호 정책 검증

Bean Validation으로 형식만 확인. 비즈니스 정책(최소 길이, 특수문자)은 커스텀 validator로.

```java
public record MemberRegisterRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8, max = 64) @ValidPassword String password
) {}

@Constraint(validatedBy = PasswordValidator.class)
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidPassword {
    String message() default "비밀번호는 영문·숫자·특수문자를 포함해야 합니다";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

---

## 요약 체크리스트

- [ ] `PasswordEncoderFactories.createDelegatingPasswordEncoder()` 또는 `BCryptPasswordEncoder` 적용
- [ ] 평문 또는 MD5/SHA-1 저장 없음
- [ ] 비밀번호 비교에 `passwordEncoder.matches()` 사용, `equals` 직접 비교 없음
- [ ] BCrypt strength ≥ 10 (기본 10, 보안 강화 시 12)
- [ ] 비밀번호 길이 검증 (`@Size(min=8)`) 적용
