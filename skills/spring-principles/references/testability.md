# 테스트 용이성

설계의 품질 척도 중 하나: "이 클래스를 `new`로 직접 생성해서 단위 테스트할 수 있는가?"

## 1) 테스트하기 쉬운 설계의 특징

- 생성자 인자로 모든 의존성을 받는다 (필드 주입 X).
- 정적(static) 메서드·상태에 의존하지 않는다.
- I/O(DB, HTTP, 파일)는 인터페이스로 추상화 → Mock 대체 가능.
- 설정 코드(`@Bean`)는 `@Configuration`에만 있다 — 객체 생성 로직과 비즈니스 로직 분리.

## 2) 인터페이스 분리 기준

복수 구현이 실제로 있거나 Mock 대체가 필요한 경우에만 인터페이스를 뽑는다.
YAGNI: 구현체가 하나뿐이면 인터페이스 불필요 (Spring Data Repository는 예외).

```java
// 외부 API 연동 — Mock 대체가 필요하므로 인터페이스 분리 적합
public interface PaymentClient {
    PaymentResult pay(PaymentRequest request);
}

@Component
public class TossPaymentClient implements PaymentClient { ... }
```

## 3) `@Bean`은 `@Configuration` 에서만

```java
// 금지 — @Service 안에서 @Bean 직접 생성
@Service
public class SomeService {
    private final OtherService other = new OtherService(); // 정적 의존
}

// 권장 — @Configuration에서 관리
@Configuration
public class AppConfig {
    @Bean
    public OtherService otherService() { return new OtherService(); }
}
```

## 4) 테스트 피라미드

```
        [E2E]          ← 소수, 느림
      [Integration]    ← 중간, @SpringBootTest + TestContainers
    [Unit]             ← 다수, 빠름, new + Mockito
```

- **Unit**: `new` 생성 + `@ExtendWith(MockitoExtension.class)`.
- **Integration**: `@SpringBootTest` + TestContainers (실제 DB).
- **E2E**: 최소화. 시나리오 중심.

```java
@ExtendWith(MockitoExtension.class)
class MemberServiceTest {

    @Mock MemberRepository memberRepository;
    @InjectMocks MemberService memberService;

    @Test
    void register_duplicateEmail_throwsException() {
        given(memberRepository.existsByEmail("test@example.com")).willReturn(true);

        assertThatThrownBy(() -> memberService.register(
            new MemberRegisterRequest("test@example.com", "pw")))
            .isInstanceOf(DuplicateEmailException.class);
    }
}
```

## 관련 원칙

- [di.md](./di.md) — 생성자 주입이 테스트 용이성의 전제조건
- [separation-of-concerns.md](./separation-of-concerns.md) — 계층 분리가 단위 테스트 범위를 좁힌다
