# @Transactional 경계 가이드

트랜잭션 경계를 어디에 두느냐는 계층 책임의 문제다.  
`spring-principles/references/separation-of-concerns.md`의 원칙과 함께 적용한다.

---

## 1) 경계 원칙

**Service 계층에만 `@Transactional`을 둔다.**

| 계층 | 트랜잭션 | 이유 |
|---|---|---|
| Controller | 금지 | HTTP 처리와 DB 트랜잭션을 분리 |
| Service | **여기에 선언** | 비즈니스 단위 = 트랜잭션 단위 |
| Repository | 금지 | 호출자가 경계를 제어해야 함 |

Repository에 `@Transactional`이 있으면 두 Repository를 하나의 논리적 작업으로 묶을 수 없다.

---

## 2) 클래스 + 메서드 선언 전략

조회 메서드가 대부분이면 클래스 레벨에 `readOnly = true`를 두고,  
변경 메서드에만 `@Transactional`을 추가로 선언한다.

```java
@Service
@Transactional(readOnly = true)   // 기본: 조회 전용
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;

    // readOnly = true 상속
    public MemberResponse findById(Long id) {
        return memberRepository.findById(id)
            .map(MemberResponse::from)
            .orElseThrow(() -> new MemberNotFoundException(id));
    }

    @Transactional   // 쓰기 작업은 readOnly = false 로 오버라이드
    public MemberResponse register(MemberRegisterRequest request) {
        Member member = Member.create(request.email(), encodePassword(request.password()));
        return MemberResponse.from(memberRepository.save(member));
    }
}
```

**`readOnly = true` 효과**

- Hibernate: dirty checking(변경 감지) 스킵 → 약간의 성능 개선
- MySQL + InnoDB: 읽기 전용 트랜잭션으로 처리 가능 (잠금 감소)
- 실수로 쓰기 시도 시 예외 발생 → 안전망

---

## 3) 전파 속성

기본값 `REQUIRED`로 충분한 경우가 대부분이다.

| 속성 | 동작 | 사용 시점 |
|---|---|---|
| `REQUIRED` (기본) | 트랜잭션 있으면 참여, 없으면 새로 시작 | 일반적인 모든 경우 |
| `REQUIRES_NEW` | 항상 새 트랜잭션. 기존 트랜잭션은 일시 중단 | 실패해도 별도 커밋이 필요한 작업 (감사 로그, 알림) |
| `NOT_SUPPORTED` | 트랜잭션 없이 실행 | 트랜잭션 컨텍스트가 오히려 방해될 때 |
| `NEVER` | 트랜잭션 있으면 예외 | 호출 시 트랜잭션이 없음을 강제 보장 |

**`REQUIRES_NEW` 사용 예시**

```java
@Service
@RequiredArgsConstructor
public class AuditService {

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void log(String action, Long userId) {
        // 주 트랜잭션이 롤백돼도 이 로그는 별도로 커밋된다
        auditRepository.save(new AuditLog(action, userId));
    }
}
```

`REQUIRES_NEW`는 새 커넥션을 획득한다. **남발하면 커넥션 풀 고갈 위험**이 있다.  
필요한 경우에만 최소한으로 사용할 것.

---

## 4) 체크드 예외와 롤백

Spring `@Transactional`의 기본 롤백 조건은 `RuntimeException`(+`Error`)뿐이다.  
체크드 예외(`IOException`, `SQLException` 등)는 기본적으로 **커밋된다.**

```java
// 체크드 예외도 롤백하려면 rollbackFor 명시
@Transactional(rollbackFor = Exception.class)
public void importFile(MultipartFile file) throws IOException { ... }
```

**권장**: 도메인 예외는 `RuntimeException`을 상속받아 설계한다.  
체크드 예외를 `rollbackFor`로 잡는 것은 외부 IO 연동처럼 불가피한 경우에만 허용.

---

## 5) 테스트에서의 트랜잭션

| 테스트 유형 | 트랜잭션 동작 |
|---|---|
| `@DataJpaTest` | 기본 롤백. 테스트 종료 후 DB 자동 정리 |
| `@SpringBootTest` | 롤백 없음. 명시적 정리 필요 |
| TestContainers + `@SpringBootTest` | 컨테이너는 남지만 각 테스트에 `@Transactional` 붙이면 롤백 가능 |

TestContainers를 사용한 통합 테스트의 상세 설정은 `spring-testing` 스킬의
`references/testcontainers.md`를 참조한다.

---

## 요약 체크리스트

- [ ] `@Transactional`이 Service 계층에만 위치
- [ ] 조회 메서드에 `readOnly = true` 적용
- [ ] 기본 전파 `REQUIRED` 사용, `REQUIRES_NEW`는 최소화
- [ ] 체크드 예외 롤백이 필요하면 `rollbackFor = Exception.class` 명시
- [ ] 도메인 예외는 `RuntimeException` 상속으로 설계
