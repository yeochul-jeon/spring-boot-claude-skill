# Regression Test #14 — spring-persistence 체크리스트 empirical 검증

날짜 초안: 2026-04-22

---

## 목적

`spring-persistence` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro16/order-api
SRC=$SANDBOX/src/main/java
```

---

## §2 grep 자동 검증

```bash
# P1: @Transactional 경계 위반 (0건이어야 PASS)
echo "=== [P1] @Transactional in Controller/Repository ===" && grep -rn "@Transactional" $SRC/com/example/orderapi/controller/ $SRC/com/example/orderapi/repository/ || echo "PASS"

# P3: EAGER fetch 명시 (0건이어야 PASS)
echo "=== [P3] FetchType.EAGER ===" && grep -rn "FetchType.EAGER" $SRC/com/example/orderapi/domain/ || echo "PASS"

# P5/K: Service가 Entity를 직접 반환 (0건이어야 PASS)
echo "=== [P5/K] Service returns Entity ===" && grep -rn "public Order\b\|public Member\b\|public Product\b\|public User\b" $SRC/com/example/orderapi/service/ || echo "PASS"

# P7: TestContainers 의존성 (1건 이상이어야 PASS)
echo "=== [P7] TestContainers ===" && grep -n "testcontainers" $SANDBOX/build.gradle.kts || echo "FAIL: testcontainers 없음"

# P8: Service readOnly 적용 확인
echo "=== [P8] @Transactional(readOnly) ===" && grep -rn "@Transactional(readOnly" $SRC/com/example/orderapi/service/ || echo "MISSING: readOnly 없음"

# 연관관계 fetch 설정 수동 확인
echo "=== [연관관계 fetch] ===" && grep -rn "@OneToMany\|@ManyToOne\|@OneToOne\|@ManyToMany" $SRC/com/example/orderapi/domain/
```

---

## §3 수동 체크리스트

```
JPA/MyBatis 선택
- [ ] JPA/MyBatis 선택을 사용자에게 확인했는가

트랜잭션 경계
- [ ] @Transactional이 Service 계층에만 위치 (Controller·Repository에 없음)
- [ ] 조회 메서드에 @Transactional(readOnly = true) 적용

DTO 분리
- [ ] Entity가 Controller 응답 타입으로 직접 노출되지 않음
- [ ] Service 메서드 반환 타입이 DTO (*Response) — Entity를 직접 반환하지 않음

의존성 주입
- [ ] 생성자 주입 + final 필드 (필드 주입 없음)

테스트
- [ ] testcontainers:mysql (또는 해당 DB) 의존성 포함

JPA 전용
- [ ] 연관관계 기본 fetch = LAZY (@ManyToOne 등 명시)
- [ ] 컬렉션 조회에 fetch join 또는 @EntityGraph 적용

spring-web 교차
- [ ] @RestControllerAdvice 등록 + ProblemDetail 반환
- [ ] @RequestBody에 @Valid 적용
- [ ] Controller 내부 @ExceptionHandler 없음

spring-principles
- [ ] spring-principles 체크리스트 전 항목 통과
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-22 | 전체 (주문 CRUD 시나리오) | FAIL (결함 5건) | 초기 baseline — retro #16 결함 수집 용도 |

### 2026-04-22 결함 목록

persistence-domain 결함 (2건):
- 결함 K: Service가 `Order` Entity를 직접 반환 (`public Order createOrder(...)` 등 4개 메서드) → SKILL.md 체크리스트에 항목 추가
- 결함 P7: TestContainers 의존성 누락 → SKILL.md 체크리스트 항목은 이미 존재, grep 자동 검증 패턴 추가

spring-web 교차 결함 (3건, spring-web 체크리스트가 이미 커버):
- W2: `@RestControllerAdvice` 없음
- W3: Controller 내부 `@ExceptionHandler` (2개)
- W5: `@RequestBody` 파라미터에 `@Valid` 미적용

> 결함 K 는 SKILL.md 항목 누락 → 추가 완료.
> 결함 P7 는 항목 존재, grep 자동화 부재 → grep 섹션 추가로 탐지 수단 강화.
> W2·W3·W5 는 spring-web 영역 — spring-persistence SKILL이 `spring-web` 체크리스트 실행을 명시하지 않아 탐지 누락 → "spring-web 체크리스트 전 항목 통과" 항목 추가.
