# Regression Test #13 — spring-web 체크리스트 empirical 검증

날짜 초안: 2026-04-22

---

## 목적

`spring-web` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro15/member-api
SRC=$SANDBOX/src/main/java
```

---

## §2 grep 자동 검증

```bash
# W1: Controller가 Entity를 직접 반환 (0건이어야 PASS)
echo "=== [W1] Entity 직접 반환 ===" && grep -rn "public Member\|public Order\|public Product\|public User" $SRC/*/controller/ || echo "PASS"

# W2: @RestControllerAdvice 없음 (1건 이상이어야 PASS)
echo "=== [W2] @RestControllerAdvice ===" && grep -rn "@RestControllerAdvice" $SRC || echo "FAIL: @RestControllerAdvice 없음"

# W3: Controller 내부 @ExceptionHandler (0건이어야 PASS)
echo "=== [W3] Controller @ExceptionHandler ===" && grep -rn "@ExceptionHandler" $SRC/*/controller/ || echo "PASS"

# W4: 에드혹 에러 Map (0건이어야 PASS)
echo "=== [W4] 에드혹 에러 Map ===" && grep -rn "Map<String.*String>.*error\|put.*\"error\"\|new HashMap" $SRC/*/controller/ || echo "PASS"

# W5a: @Valid 없는 @RequestBody
echo "=== [W5a] @Valid 미적용 ===" && grep -rn "@RequestBody" $SRC/*/controller/ | grep -v "@Valid" || echo "PASS"

# W5b: @RequestBody에 Map 사용 (0건이어야 PASS)
echo "=== [W5b] @RequestBody Map ===" && grep -rn "@RequestBody Map<" $SRC/*/controller/ || echo "PASS"

# W6: URL 패턴 수동 확인
echo "=== [W6] URL 패턴 ===" && grep -rn "@RequestMapping" $SRC/*/controller/
```

---

## §3 수동 체크리스트

```
Controller 반환 타입
- [ ] Controller 메서드 반환이 *Response 또는 ResponseEntity<*Response>
- [ ] @RequestBody에 Map<String, String> 없음 — *Request record 사용

Validation
- [ ] @RequestBody 파라미터에 @Valid 적용

예외 처리
- [ ] @RestControllerAdvice 등록 + ProblemDetail 반환
- [ ] 예외 → HTTP 상태 매핑이 @RestControllerAdvice 내에 문서화
- [ ] Controller 클래스 내부에 @ExceptionHandler 없음
- [ ] 에드혹 에러 JSON (Map) 없음

URL 규칙
- [ ] 명사 복수 + kebab-case (/members, /order-items)

spring-principles
- [ ] @Autowired 필드 주입 없음
- [ ] @Transactional이 Controller에 없음
- [ ] private final 필드 사용 (생성자 주입)
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-22 | 전체 (회원 가입·수정 시나리오) | FAIL (결함 7건) | 초기 baseline — retro #15 결함 수집 용도 |

### 2026-04-22 결함 목록

- 결함 J: `@RequestBody Map<String,String>` — `*Request` DTO 미사용 → SKILL.md 체크리스트에 항목 추가
- 결함 W1: Controller가 `Member` Entity 직접 반환 (3개 메서드)
- 결함 W2: `@RestControllerAdvice` 없음
- 결함 W3: Controller 내부 `@ExceptionHandler`
- 결함 W4: `ProblemDetail` 미사용, 에드혹 `Map<String,String>` 에러 반환
- 결함 W5: `@RequestBody`에 `@Valid` 미적용
- 결함 W6: URL `/member` 단수

> 결함 W1~W6 는 SKILL.md 에 체크리스트 항목이 이미 존재(W5+ 결함 J 신규) → grep 자동 검증 패턴 추가로 보강.
> 결함 J 는 항목 누락 → 체크리스트에 추가함.
