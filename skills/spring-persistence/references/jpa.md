# JPA 패턴 가이드

JPA/Hibernate를 선택했을 때 따라야 할 Entity 설계, Repository, N+1 회피, Auditing 표준.  
`spring-principles/templates/dto-entity-separation.md`와 `rich-domain.md`와 함께 사용한다.

---

## 1) Entity 설계

### 기본 규칙

```java
@Entity
@Table(name = "members")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)  // JPA 기본 생성자, 외부 직접 생성 금지
public class Member extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)  // MySQL: IDENTITY, Sequence DB는 SEQUENCE
    private Long id;

    @Column(nullable = false, unique = true, length = 100)
    private String email;

    @Column(nullable = false)
    private String password;

    // 팩토리 메서드로 생성 통제
    public static Member create(String email, String encodedPassword) {
        Member member = new Member();
        member.email = email;
        member.password = encodedPassword;
        return member;
    }
}
```

**규칙 요약**

| 항목 | 권장 | 안티패턴 |
|---|---|---|
| 기본 생성자 | `protected` | `public` |
| 필드 접근 | 팩토리 메서드 / 도메인 메서드로 통제 | Setter로 상태 직접 변경 |
| ID 전략 | MySQL: `IDENTITY` | `AUTO` (DB 종류에 무관하게 일관성 저하) |
| 상속 | `@MappedSuperclass`로 공통 필드 추출 | 각 Entity에 `createdAt` 중복 |

---

## 2) 연관관계

### 단방향 우선 원칙

```java
// 양방향이 필요한 경우에만 mappedBy 추가
@Entity
public class Order {

    @ManyToOne(fetch = FetchType.LAZY)  // 항상 LAZY
    @JoinColumn(name = "member_id")
    private Member member;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItem> items = new ArrayList<>();
}
```

**핵심 규칙**

- 모든 `@ManyToOne`, `@OneToOne` — `fetch = FetchType.LAZY` 명시  
  (기본값 `EAGER`는 N+1을 유발한다)
- `@OneToMany` 기본이 `LAZY`이나 명시 권장
- 양방향은 연관관계 편의 메서드로 동기화

```java
public void addItem(OrderItem item) {
    items.add(item);
    item.setOrder(this);  // 양방향 동기화
}
```

---

## 3) Repository

```java
public interface MemberRepository extends JpaRepository<Member, Long> {

    Optional<Member> findByEmail(String email);

    // 복잡한 조건은 @Query (JPQL, 엔티티 기준)
    @Query("SELECT m FROM Member m WHERE m.createdAt >= :since AND m.active = true")
    List<Member> findActiveAfter(@Param("since") LocalDateTime since);
}
```

**선택 기준**

| 쿼리 유형 | 방식 |
|---|---|
| 단순 조건 (`findByXxx`) | 메서드 네이밍 |
| 조인·다중 조건 | `@Query` JPQL |
| 통계·네이티브 SQL | `@Query(nativeQuery = true)` — 남발 금지 |
| 복잡한 동적 쿼리 | `Specification` 또는 QueryDSL (도입 비용 고려) |

---

## 4) N+1 회피

### 문제 패턴 (Before)

```java
// orders 목록을 조회하면 각 order마다 items를 추가 쿼리 → N+1
List<Order> orders = orderRepository.findAll();
orders.forEach(o -> o.getItems().size()); // N번 추가 쿼리 발생
```

### 해결 1: fetch join (After)

```java
@Query("SELECT DISTINCT o FROM Order o JOIN FETCH o.items WHERE o.member.id = :memberId")
List<Order> findWithItemsByMemberId(@Param("memberId") Long memberId);
```

### 해결 2: @EntityGraph (After)

```java
@EntityGraph(attributePaths = {"items"})
List<Order> findByMemberId(Long memberId);
```

**선택 기준**

| 상황 | 방식 |
|---|---|
| 단일 메서드에만 필요 | `@Query` + `JOIN FETCH` |
| 여러 메서드에 재사용 | `@EntityGraph` |
| 페이징 + 컬렉션 fetch join | **금지** (HibernateException). `@EntityGraph` + `@QueryHints` 조합 또는 배치 크기 설정 |

**페이징 시 컬렉션 fetch join 대안**

```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 100  # IN 절 배치로 N+1 완화
```

---

## 5) Auditing

```java
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
@Getter
public abstract class BaseEntity {

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}
```

`@SpringBootApplication` 클래스 또는 별도 `@Configuration`에 `@EnableJpaAuditing` 추가:

```java
@EnableJpaAuditing
@SpringBootApplication
public class Application { ... }
```

---

## 6) Rich Domain 연동

비즈니스 규칙은 Entity 메서드 안에 둔다. Service가 Entity 내부 상태를 직접 조작하는
Anemic Domain을 피한다.  
상세는 `spring-principles/templates/rich-domain.md` 참조.

```java
// 안티패턴: Service에서 상태 직접 변경
order.setStatus(OrderStatus.CANCELLED);

// 권장: Entity 메서드로 도메인 규칙 캡슐화
order.cancel();  // 내부에서 상태 전이 + 유효성 검사
```

---

## 요약 체크리스트

- [ ] 기본 생성자 `protected`, 생성은 팩토리 메서드
- [ ] 연관관계 기본 `fetch = LAZY`
- [ ] 컬렉션 조회에 fetch join 또는 `@EntityGraph` 적용
- [ ] 페이징 + 컬렉션 fetch join 조합 사용하지 않음
- [ ] `@EnableJpaAuditing` + `BaseEntity` 적용
- [ ] 비즈니스 로직이 Entity 메서드에 위치 (Anemic Domain 없음)
