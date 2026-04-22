# Regression Test #12 — spring-principles 체크리스트 empirical 검증

날짜 초안: 2026-04-22

---

## 목적

`spring-principles` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
# Sandbox 경로
SANDBOX=/Users/cjenm/github/test-retro14/order-api
SRC=$SANDBOX/src/main/java
```

---

## §2 grep 자동 검증

```bash
# A: @Autowired 필드 주입 탐지 (0건이어야 PASS)
echo "=== [A] @Autowired ===" && grep -rn "@Autowired" $SRC || echo "PASS"

# B: Controller 메서드가 Entity 직접 반환 (0건이어야 PASS)
echo "=== [B] Entity 직접 반환 ===" && grep -rn "public Order\|public Product\|public Member" $SRC/*/controller/ || echo "PASS"

# C: @Transactional이 Controller에 위치 (0건이어야 PASS)
echo "=== [C] Controller @Transactional ===" && grep -rn "@Transactional" $SRC/*/controller/ || echo "PASS"

# F: VO에 setter 존재 (0건이어야 PASS)
echo "=== [F] VO setter ===" && find $SRC -name "Money.java" -o -name "*Vo.java" | xargs grep -ln "public void set" 2>/dev/null || echo "PASS"

# G: private final 필드 있음 (1건 이상이어야 PASS)
echo "=== [G] private final ===" && grep -rn "private final" $SRC | wc -l
```

---

## §3 수동 체크리스트

```
DI & 의존성
- [ ] @Autowired 필드 주입이 없음
- [ ] 주입 받는 모든 필드가 private final
- [ ] 생성자가 하나면 @RequiredArgsConstructor, 여럿이면 명시 생성자

계층 분리
- [ ] Controller가 Entity를 직접 반환하지 않음 (DTO 매핑)
- [ ] Controller가 Repository를 직접 호출하지 않음
- [ ] Service 계층에 @Transactional 이 위치함
- [ ] @Transactional(readOnly = true) 를 조회 메서드에 적용했는가

Domain
- [ ] 비즈니스 규칙(검증, 상태 전이)이 Service가 아닌 Entity/VO 내부에 있음
- [ ] Primitive Obsession이 있는 값은 VO로 추출했는가
- [ ] VO는 setter가 없다 (불변)

테스트 용이성
- [ ] new로 직접 생성 가능한 클래스 (불필요한 정적 의존 없음)
- [ ] @Bean은 @Configuration 에만 있음
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-22 | 전체 (b)확장 시나리오 | FAIL (결함 7건) | 초기 baseline — retro #14 결함 수집 용도 |

### 2026-04-22 결함 목록

- 결함 I: VO setter 허용 — SKILL.md 체크리스트에 "VO 불변성" 항목 없음 → 추가함
- 결함 A: @Autowired 필드 주입 (Controller·Service)
- 결함 B: Controller가 Order Entity 직접 반환
- 결함 C: @Transactional 이 Controller에 배치
- 결함 D: 조회 메서드에 readOnly=true 없음
- 결함 E: 상태 전이 로직이 Service에 있음 (Anemic Entity)
- 결함 G: private final 필드 전무

> 결함 A·B·C·D·E·G 는 SKILL.md 에 이미 항목 존재 → grep 자동 검증 패턴 추가로 보강.
> 결함 I 는 항목 누락 → 체크리스트에 추가함.
