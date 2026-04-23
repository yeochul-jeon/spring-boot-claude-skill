# Regression Test #24 — spring-cache 체크리스트 empirical 검증

날짜 초안: 2026-04-23

---

## 목적

`spring-cache` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro24-cache      # BASELINE
SRC=$SANDBOX/src/main/java

SANDBOX_V2=/Users/cjenm/github/test-retro24-cache-v2  # 2차 회전
SRC_V2=$SANDBOX_V2/src/main/java
```

시나리오: "상품 상세 조회(`GET /products/{id}`)를 캐시. 수정·삭제 시 무효화.
인스턴스 다중 배포 환경."

---

## §2 grep 자동 검증

**주의: 아래 스크립트는 BASELINE과 V2 각각 변수를 바꿔서 별도 실행한다.**
- BASELINE: `SANDBOX=$BASELINE_SANDBOX; SRC=$SANDBOX/src/main/java`
- 2차 회전: `SANDBOX=$SANDBOX_V2; SRC=$SRC_V2`

```bash
# C1: @Cacheable key 미명시 (key 속성 없는 @Cacheable — 수동 확인 필요)
echo "=== [C1] @Cacheable key 명시 ==="
grep -rn "@Cacheable" $SRC/ | grep -v 'key\s*=' | grep -v "//\|grep"
echo "(위 결과 있으면 key 표현식 확인 필요)"

# C2: @EnableCaching 설정 존재 (1건 이상이어야 PASS)
echo "=== [C2] @EnableCaching ==="
grep -rn "@EnableCaching" $SRC/ || echo "FAIL: @EnableCaching 없음"

# C3: TTL 설정 확인 (수동 확인 필수)
# Caffeine: expireAfterWrite(TTL)/expireAfterAccess(TTI), Redis Java: entryTtl/@TimeToLive
# Redis yml: spring.cache.redis.time-to-live → 검증 대상 $SANDBOX의 resources/ 를 스캔
# 주의: grep 은 TTL 문자열 존재만 확인 — 모든 @Cacheable 캐시에 TTL이 적용되는지 수동 확인 필수
echo "=== [C3] TTL 설정 ==="
grep -rn "expireAfterWrite\|expireAfterAccess\|entryTtl\|TimeToLive" $SRC/ 2>/dev/null | head -5
grep -rn "time-to-live" $SANDBOX/src/main/resources/ 2>/dev/null | head -3
echo "MANUAL: 0건이면 FAIL(TTL 없음); 1건 이상이면 전체 캐시 커버리지 수동 확인"

# C4: null 캐시 방지 설정 (1건 이상이어야 PASS)
echo "=== [C4] null 캐시 방지 ==="
grep -rn "disableCachingNullValues\|unless.*null\|unless = " $SRC/ | head -3
echo "(위 결과 1건 이상 → PASS)"
```

---

## §3 수동 체크리스트

```
캐시 저장소
- [ ] 로컬(Caffeine) vs 분산(Redis) 선택을 명시적으로 결정 (다중 인스턴스 → Redis 필수)
- [ ] @EnableCaching + CacheManager Bean 설정 존재

캐시 어노테이션
- [ ] @Cacheable key 표현식 명시 (기본 키 사용 금지)
- [ ] TTL이 모든 캐시에 설정됨 (Java config: entryTtl/expireAfterWrite, yml: time-to-live)
- [ ] null 캐시 방지: disableCachingNullValues() 또는 unless = "#result == null"
- [ ] @CacheEvict 타이밍이 데이터 일관성 요건에 맞게 설정됨 (allEntries vs key 기반)
- [ ] 캐시 키 충돌 가능성 검토 (여러 메서드가 같은 캐시명 공유 시)

spring-principles
- [ ] 생성자 주입 100% (@Autowired 필드 없음)
- [ ] Service 반환 타입이 DTO (Entity 직접 반환 없음)
- [ ] spring-principles 체크리스트 전 항목 통과
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-23 | BASELINE (맨세션, productCache) | C1~C4 PASS | 실제 결함 0건; 탐지 공백 2건 (C3_GREP_YML, C3_CAFFEINE_TTI) |
| 2026-04-23 | 2차 회전 (SKILL.md 로드 후 재생성) | C1~C4 PASS | 결함 0건; unless 이중 방어 추가됨 |

### 2026-04-23 BASELINE 탐지 공백 목록

| 코드 | 결함 | 분류 |
|------|------|------|
| C3_GREP_YML | C3 grep이 `$SRC/`(Java)만 스캔 — `spring.cache.redis.time-to-live` yml 전용 설정 시 false-PASS 위험 | 탐지 공백 — grep 패턴에 `resources/` 스캔 추가 |
| C3_CAFFEINE_TTI | `expireAfterAccess`(TTI) 가 C3 패턴에 없음 — Caffeine TTI 설정 시 탐지 공백 | 탐지 공백 — grep 패턴에 `expireAfterAccess` 추가 |

**참고**: 두 공백 모두 이번 BASELINE에서는 Java config 기반 Redis 사용으로 실증되지 않음.
BASELINE 코드 자체는 SKILL 지침 없이도 모범 패턴을 생성했다.

### 수정된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `skills/spring-cache/SKILL.md` | C3 grep: `expireAfterAccess` 추가; `resources/`의 `time-to-live` 스캔 추가; 자동 PASS → 수동 확인 필수로 격상 (codex 리뷰 반영) |
| `tests/regression-24-cache-checklist.md` (본 파일) | §2 C3: BASELINE/V2 분리 실행 안내; 수동 확인 echo 추가 (codex 리뷰 반영) |
