# Regression Test #22 — §A meta-regression 확장 + 2차 회전 (retro #22)

날짜 초안: 2026-04-23

---

## 목적

retro #20 §A 는 스킬별 **1개 핵심 규칙** 만 자기참조 위반 검증.
본 테스트에서 **3~5개 규칙**으로 확장하고, 기존 4개 스킬
(spring-principles/web/persistence/security)의 **2차 회전 정적 재검증**을 병행한다.

허용 예외 기준 (regression-17 §A 동일):
- "금지", "// 안티패턴", "Before" 블록 내 예시는 허용
- grep 탐지 명령문 자체에 심볼이 등장하는 것은 허용
- Spring Boot 이외 외부 라이브러리 버전은 허용
- 문서 작성 기준 표기 메타 주석은 허용

---

## §A 확장 — 스킬별 규칙 확장 grep

```bash
SKILLS=/Users/cjenm/github/spring-boot-claude-skill/skills

# ─────────────────────────────────────────
# spring-principles (확장: A2a~A2d)
# ─────────────────────────────────────────

# A2a: @Autowired 필드 주입 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A2a] spring-principles @Autowired ==="
grep -rn "@Autowired" $SKILLS/spring-principles/ \
  | grep -v "금지\|안티패턴\|BAD\|Before\b\|// ×\|WRONG\|grep -rn\|- \[ \]" \
  || echo "PASS"

# A2b: Controller Entity 직접 반환 예시 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A2b] spring-principles Entity 반환 예시 ==="
grep -rn "public Order\b\|public Member\b\|public Product\b" $SKILLS/spring-principles/ \
  | grep -v "안티패턴\|Before\b\|grep -rn\|anti\|BAD\|WRONG" \
  || echo "PASS"

# A2c: Controller @Transactional (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A2c] spring-principles Controller @Transactional ==="
grep -rn "@Transactional" $SKILLS/spring-principles/ \
  | grep -v "Service\|readOnly\|rollbackFor\|propagation\|grep -rn\|금지\|안티패턴\|- \[ \]\|경계\|배치" \
  || echo "PASS"

# A2d: VO setter (안티패턴 Before 블록 이외에서는 0건이어야 PASS)
echo "=== [A2d] spring-principles VO setter ==="
grep -rn "public void set" $SKILLS/spring-principles/ \
  | grep -v "grep -rn\|Before\b\|금지\|##.*금지 패턴\|안티패턴" \
  || echo "PASS"

# ─────────────────────────────────────────
# spring-web (확장: A3a~A3e)
# ─────────────────────────────────────────

# A3a: Controller Entity 반환 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A3a] spring-web Entity 반환 ==="
grep -rn "public Member\b\|public Order\b\|public Product\b\|public User\b" \
  $SKILLS/spring-web/ \
  | grep -v "안티패턴\|BAD\|Before\b\|grep -rn" \
  || echo "PASS"

# A3b: @RestControllerAdvice 존재 (1건 이상이어야 PASS)
echo "=== [A3b] spring-web @RestControllerAdvice 존재 ==="
grep -rn "@RestControllerAdvice" $SKILLS/spring-web/ \
  | grep -v "grep -rn\|- \[ \]\|존재 확인" \
  | head -3
echo "(위 결과 1건 이상 → PASS)"

# A3c: @RequestBody Map< 금지 예시 없음 (안티패턴 맥락 제외, 0건이어야 PASS)
echo "=== [A3c] spring-web @RequestBody Map< ==="
grep -rn "@RequestBody Map<" $SKILLS/spring-web/ \
  | grep -v "grep -rn\|금지\|- \[ \]\|안티패턴" \
  || echo "PASS"

# A3d: W5a — @Valid 미적용 (multi-line aware)
echo "=== [A3d] spring-web W5a @Valid 미적용 (skill 문서 내) ==="
W5A_MISS=""
for f in $(find $SKILLS/spring-web -name "*.java" 2>/dev/null); do
  HITS=$(tr '\n' ' ' < "$f" | grep -oE '@RequestBody[^,)]{0,200}[,)]' | grep -v '@Valid')
  [ -n "$HITS" ] && printf '%s:\n%s\n' "$f" "$HITS" && W5A_MISS="yes"
done
[ -z "$W5A_MISS" ] && echo "PASS (java 파일 없음 — 문서 전용 스킬 정상)"

# A3e: ProblemDetail 사용 확인 (1건 이상이어야 PASS)
echo "=== [A3e] spring-web ProblemDetail 사용 ==="
grep -rn "ProblemDetail" $SKILLS/spring-web/ | grep -v "grep -rn\|- \[ \]" | head -3
echo "(위 결과 1건 이상 → PASS)"

# ─────────────────────────────────────────
# spring-persistence (확장: A4a~A4d)
# ─────────────────────────────────────────

# A4a: @Transactional 경계 위반 예시 (Service 외 맥락, 0건이어야 PASS)
echo "=== [A4a] spring-persistence @Transactional 경계 위반 ==="
grep -rn "@Transactional" $SKILLS/spring-persistence/ \
  | grep -v "Service\|readOnly\|transaction\.md\|rollbackFor\|propagation\|grep -rn\|금지\|안티패턴\|- \[ \]\|경계\|계층" \
  || echo "PASS"

# A4b: FetchType.EAGER 명시 예시 (0건이어야 PASS)
echo "=== [A4b] spring-persistence FetchType.EAGER ==="
grep -rn "FetchType.EAGER" $SKILLS/spring-persistence/ \
  | grep -v "grep -rn\|금지\|안티패턴\|- \[ \]" \
  || echo "PASS"

# A4c: Service Entity 직접 반환 예시 (0건이어야 PASS)
echo "=== [A4c] spring-persistence Service Entity 반환 ==="
grep -rn "public Order\b\|public Member\b\|public Product\b\|public User\b" \
  $SKILLS/spring-persistence/ \
  | grep -v "안티패턴\|Before\b\|grep -rn\|BAD" \
  || echo "PASS"

# A4d: TestContainers 참조 (1건 이상이어야 PASS)
echo "=== [A4d] spring-persistence TestContainers 참조 ==="
grep -rn "testcontainers\|TestContainers" $SKILLS/spring-persistence/ | head -3
echo "(위 결과 1건 이상 → PASS)"

# ─────────────────────────────────────────
# spring-security (확장: A5a~A5d)
# ─────────────────────────────────────────

# A5a: WebSecurityConfigurerAdapter (0건이어야 PASS)
echo "=== [A5a] spring-security WebSecurityConfigurerAdapter ==="
grep -rn "WebSecurityConfigurerAdapter" $SKILLS/spring-security/ \
  | grep -v "사용하지 않는다\|금지\|grep -rn\|안티패턴\|- \[ \]" \
  || echo "PASS"

# A5b: NoOpPasswordEncoder (0건이어야 PASS)
echo "=== [A5b] spring-security NoOpPasswordEncoder ==="
grep -rn "NoOpPasswordEncoder" $SKILLS/spring-security/ \
  | grep -v "금지\|grep -rn\|안티패턴\|- \[ \]" \
  || echo "PASS"

# A5c: DelegatingPasswordEncoder 사용 확인 (1건 이상이어야 PASS)
echo "=== [A5c] spring-security DelegatingPasswordEncoder ==="
grep -rn "DelegatingPasswordEncoder\|PasswordEncoderFactories" $SKILLS/spring-security/ \
  | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A5d: wildcard origin + credentials (0건이어야 PASS)
echo "=== [A5d] spring-security wildcard CORS ==="
grep -rn 'allowedOrigins.*"\*"' $SKILLS/spring-security/ \
  | grep -v "grep -rn\|금지\|안티패턴" \
  || echo "PASS"

# ─────────────────────────────────────────
# spring-testing (확장: A6a~A6e)
# ─────────────────────────────────────────

# A6a: H2 의존성 (0건이어야 PASS)
echo "=== [A6a] spring-testing H2 ==="
grep -rn "h2\|H2Database\|H2Dialect" $SKILLS/spring-testing/ \
  | grep -v "grep -rn\|금지\|인메모리.*금지\|- \[ \]\|없음\|H2 없음" \
  || echo "PASS"

# A6b: @MockBean 잔존 (0건이어야 PASS)
echo "=== [A6b] spring-testing @MockBean ==="
grep -rn "@MockBean" $SKILLS/spring-testing/ \
  | grep -v "retro\|→\|마이그레이션\|deprecated\|교체\|grep -rn\|- \[ \]" \
  || echo "PASS"

# A6c: @MockitoBean 사용 (1건 이상이어야 PASS)
echo "=== [A6c] spring-testing @MockitoBean ==="
grep -rn "@MockitoBean" $SKILLS/spring-testing/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A6d: withReuse (1건 이상이어야 PASS)
echo "=== [A6d] spring-testing withReuse ==="
grep -rn "withReuse" $SKILLS/spring-testing/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A6e: Fixtures/ObjectMother (1건 이상이어야 PASS)
echo "=== [A6e] spring-testing Fixtures/ObjectMother ==="
grep -rn "Fixtures\|ObjectMother" $SKILLS/spring-testing/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# ─────────────────────────────────────────
# spring-init (확장: A1a~A1c)
# ─────────────────────────────────────────

# A1a: Boot 패치 버전 하드코딩 (0건이어야 PASS — 라이브러리 버전 허용)
echo "=== [A1a] spring-init Boot 버전 하드코딩 ==="
grep -rEn '[0-9]+\.[0-9]+\.[0-9]+' $SKILLS/spring-init/ \
  | grep -v "jjwt\|mybatis\|latestVersion\|fetch-latest\|dependency-management\|testcontainers\|mapstruct\|1\.1\|4\.x\|// \|#\|gradle-version" \
  || echo "PASS"

# A1b: fetch-latest-versions.sh 참조 (1건 이상이어야 PASS)
echo "=== [A1b] spring-init fetch-latest-versions.sh 참조 ==="
grep -rn "fetch-latest-versions" $SKILLS/spring-init/ | head -3
echo "(위 결과 1건 이상 → PASS)"

# A1c: 결정 트리 참조 (1건 이상이어야 PASS)
echo "=== [A1c] spring-init decision-tree 참조 ==="
grep -rn "decision-tree\|결정 트리" $SKILLS/spring-init/ | head -3
echo "(위 결과 1건 이상 → PASS)"

# ─────────────────────────────────────────
# spring-batch (확장: A7a~A7d)
# ─────────────────────────────────────────

# A7a: Spring Boot 버전 하드코딩 없음 — Boot 좌표만 타겟팅 (외부 라이브러리 버전은 자연 통과)
echo "=== [A7a] spring-batch Boot 버전 하드코딩 ==="
UNSAFE=$(grep -rnE 'spring-boot.*[0-9]+\.[0-9]+\.[0-9]+|springframework\.boot.*[0-9]+\.[0-9]+\.[0-9]+' $SKILLS/spring-batch/ \
  | grep -v "latestVersion\|//\|#")
[ -n "$UNSAFE" ] && echo "$UNSAFE" && echo "FAIL: Spring Boot 버전 하드코딩 발견" || echo "PASS"

# A7b/A7c: 존재-확인 규칙 — 목차/다이어그램도 통과 가능한 구조적 한계 (known-limitation).
#          실질 위반은 BASELINE empirical 사이클(retro #23)이 커버.

# A7b: JobBuilder/StepBuilder DSL 참조 (1건 이상이어야 PASS)
echo "=== [A7b] spring-batch JobBuilder/StepBuilder ==="
grep -rn "JobBuilder\|StepBuilder" $SKILLS/spring-batch/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A7c: ItemReader/JdbcCursorItemReader/JpaPagingItemReader 참조 (1건 이상이어야 PASS)
echo "=== [A7c] spring-batch ItemReader ==="
grep -rn "ItemReader\|JdbcCursorItemReader\|JpaPagingItemReader\|RepositoryItemReader" \
  $SKILLS/spring-batch/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A7d: chunk() 호출 참조 (1건 이상이어야 PASS)
# 주의: .<T,R>chunk(...) type witness + whitespace 변형 대응 — `chunk\s*\(`
echo "=== [A7d] spring-batch chunk() 참조 ==="
grep -rnE "chunk\s*\(" $SKILLS/spring-batch/ \
  | grep -v "grep -rn\|# .*chunk\|chunk size 가\|권장 chunk" | head -3
echo "(위 결과 1건 이상 → PASS)"

# ─────────────────────────────────────────
# spring-cache (확장: A8a~A8d)
# ─────────────────────────────────────────

# A8a: Spring Boot 버전 하드코딩 없음 — Boot 좌표만 타겟팅
echo "=== [A8a] spring-cache Boot 버전 하드코딩 ==="
UNSAFE=$(grep -rnE 'spring-boot.*[0-9]+\.[0-9]+\.[0-9]+|springframework\.boot.*[0-9]+\.[0-9]+\.[0-9]+' $SKILLS/spring-cache/ \
  | grep -v "latestVersion\|//\|#")
[ -n "$UNSAFE" ] && echo "$UNSAFE" && echo "FAIL: Spring Boot 버전 하드코딩 발견" || echo "PASS"

# A8b: @EnableCaching 참조 (FQCN 변형 포함, 1건 이상이어야 PASS)
echo "=== [A8b] spring-cache @EnableCaching ==="
grep -rnE "@EnableCaching|springframework\.cache\.annotation\.EnableCaching" \
  $SKILLS/spring-cache/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A8c: unless 또는 SpEL null 방어 (존재-확인 — disableCachingNullValues 단독 케이스는 known-limitation)
echo "=== [A8c] spring-cache unless/SpEL null 방어 ==="
grep -rn "unless\|#result.*null\|== null" $SKILLS/spring-cache/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A8d: TTL 설정 (@TimeToLive / time-to-live 대체 표현 포함, 1건 이상이어야 PASS)
echo "=== [A8d] spring-cache TTL ==="
grep -rnE "expireAfterWrite|entryTtl|ttl:|@TimeToLive|time-to-live" \
  $SKILLS/spring-cache/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# ─────────────────────────────────────────
# spring-observability (확장: A9a~A9d)
# ─────────────────────────────────────────

# A9a: Spring Boot 버전 하드코딩 없음 — Boot 좌표만 타겟팅
echo "=== [A9a] spring-observability Boot 버전 하드코딩 ==="
UNSAFE=$(grep -rnE 'spring-boot.*[0-9]+\.[0-9]+\.[0-9]+|springframework\.boot.*[0-9]+\.[0-9]+\.[0-9]+' $SKILLS/spring-observability/ \
  | grep -v "latestVersion\|//\|#")
[ -n "$UNSAFE" ] && echo "$UNSAFE" && echo "FAIL: Spring Boot 버전 하드코딩 발견" || echo "PASS"

# A9b: Actuator include wildcard 노출 (YAML 쌍/단따옴표 + properties 비인용 = 세 변형 탐지)
echo "=== [A9b] spring-observability Actuator wildcard 노출 ==="
grep -rnE 'include[ =:"'"'"']*\*' $SKILLS/spring-observability/ \
  | grep -v "금지\|안티패턴\|Before\|BAD\|WRONG\|grep -rn\|- \[ \]\|변형 모두\|세 변형" \
  || echo "PASS"

# A9c: LogstashEncoder 또는 logging.structured.format 참조 (존재-확인)
#      주의: "금지" 같은 부정 문장도 통과 가능 — known-limitation. 실질 검증은 empirical(retro #25).
echo "=== [A9c] spring-observability LogstashEncoder/structured.format ==="
grep -rn "LogstashEncoder\|logging\.structured\.format" $SKILLS/spring-observability/ \
  | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A9d: probability 키 참조 (flat `sampling.probability` + YAML 중첩 `probability:` 모두 탐지)
echo "=== [A9d] spring-observability sampling probability ==="
grep -rn "sampling\.probability\|probability:" $SKILLS/spring-observability/ \
  | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# ─────────────────────────────────────────
# spring-async (확장: A10a~A10e)
# ─────────────────────────────────────────

# A10a: Spring Boot 버전 하드코딩 없음 — Boot 좌표만 타겟팅
echo "=== [A10a] spring-async Boot 버전 하드코딩 ==="
UNSAFE=$(grep -rnE 'spring-boot.*[0-9]+\.[0-9]+\.[0-9]+|springframework\.boot.*[0-9]+\.[0-9]+\.[0-9]+' $SKILLS/spring-async/ \
  | grep -v "latestVersion\|//\|#")
[ -n "$UNSAFE" ] && echo "$UNSAFE" && echo "FAIL: Spring Boot 버전 하드코딩 발견" || echo "PASS"

# A10b: SimpleAsyncTaskExecutor (안티패턴/grep 레이블 맥락 외 0건이어야 PASS)
# `echo "=== [AS1] ..."` 라인은 grep 명령 레이블 — `=== [AS` 앵커로 좁게 제외
echo "=== [A10b] spring-async SimpleAsyncTaskExecutor ==="
grep -rn "SimpleAsyncTaskExecutor" $SKILLS/spring-async/ \
  | grep -v "절대 원칙\|사용하지 않는다\|사용 금지\|# AS1\|grep -rn\|=== \[AS\|- \[ \]\|banned\|// 금지" \
  || echo "PASS"

# A10c: new Thread( / Executors.newCachedThreadPool (bash 주석 설명 맥락 외 0건이어야 PASS)
# `# new Thread( — 원시 스레드...` 는 bash 주석 — grep -rn 출력 `:N:# ` 앵커로 좁게 제외
echo "=== [A10c] spring-async 비관리 스레드 직접 생성 ==="
grep -rn "new Thread(\|Executors\.newCachedThreadPool\|Executors\.newSingleThreadExecutor" \
  $SKILLS/spring-async/ \
  | grep -Ev "금지|안티패턴|// |grep -rn|UNSAFE|- \[ \]|WARN|:[0-9]+:[[:space:]]*# " \
  || echo "PASS"

# A10d: @EnableAsync 참조 (FQCN 변형 포함, 1건 이상이어야 PASS)
echo "=== [A10d] spring-async @EnableAsync ==="
grep -rnE "@EnableAsync|springframework\.scheduling\.annotation\.EnableAsync" \
  $SKILLS/spring-async/ | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"

# A10e: exceptionally/handle/handleAsync 예외 처리 참조 (1건 이상이어야 PASS)
echo "=== [A10e] spring-async exceptionally/handle ==="
grep -rnE "exceptionally|\.handle\(|handleAsync" $SKILLS/spring-async/ \
  | grep -v "grep -rn" | head -3
echo "(위 결과 1건 이상 → PASS)"
```

---

## §B 2차 회전 — 기존 4개 스킬 정적 재검증

retro #14~#17 은 BASELINE sandbox 만 생성되고 2차 회전(SKILL 로드 후 재실행) sandbox 가 없다.
정적 재검증: 각 SKILL.md 에 등록된 grep 패턴을 스킬 문서 자신에 직접 적용해
**자기참조 위반이 없음을 확인한다** (retro #22 분석 실행).

실행 결과는 §4 결과표에 기록.

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-23 | §A 확장 — spring-principles (A2a~A2d) | PASS | @Autowired·setter·@Transactional 모두 anti-pattern Before 맥락; Entity 반환 예시도 Before·grep 명령문 맥락 |
| 2026-04-23 | §A 확장 — spring-web (A3a~A3e) | PASS | W1·W3·W4·W5b·ProblemDetail 모두 정상; @ExceptionHandler 는 @RestControllerAdvice 클래스 내 정상 등장 |
| 2026-04-23 | §A 확장 — spring-persistence (A4a~A4d) | PASS | @Transactional line 102 = MemberService 예시(Service 계층); FetchType.EAGER 0건; TestContainers 참조 존재 |
| 2026-04-23 | §A 확장 — spring-security (A5a~A5d) | PASS | WebSecurityConfigurerAdapter·NoOpPasswordEncoder 0건; DelegatingPasswordEncoder 정상 등장; wildcard 0건 |
| 2026-04-23 | §A 확장 — spring-testing (A6a~A6e) | PASS | H2 0건; @MockBean 0건; @MockitoBean·withReuse·Fixtures 각 1건+ |
| 2026-04-23 | §A 확장 — spring-init (A1a~A1c) | PASS | testcontainers/mapstruct 버전은 라이브러리 버전으로 허용; fetch-latest-versions 참조 존재; decision-tree 참조 존재 |
| 2026-04-23 | §B 2차 회전 — spring-principles | PASS | 자기참조 위반 0건 |
| 2026-04-23 | §B 2차 회전 — spring-web | PASS | 자기참조 위반 0건 (W5a multi-line scanner 포함) |
| 2026-04-23 | §B 2차 회전 — spring-persistence | PASS | 자기참조 위반 0건 |
| 2026-04-23 | §B 2차 회전 — spring-security | PASS | 자기참조 위반 0건 |
| 2026-04-23 | §A 확장 — spring-batch (A7a~A7d) | PASS | 버전 하드코딩 0건; JobBuilder·ItemReader·chunk() 참조 각 1건+ |
| 2026-04-23 | §A 확장 — spring-cache (A8a~A8d) | PASS | 버전 하드코딩 0건; @EnableCaching·unless·TTL 참조 각 1건+ |
| 2026-04-23 | §A 확장 — spring-observability (A9a~A9d) | PASS | 버전 하드코딩 0건; wildcard 0건; LogstashEncoder·sampling 참조 각 1건+ |
| 2026-04-23 | §A 확장 — spring-async (A10a~A10e) | PASS | 버전 하드코딩 0건; SimpleAsyncTaskExecutor·new Thread( 모두 허용 맥락; @EnableAsync·exceptionally 참조 각 1건+ |
| 2026-04-23 | §A 보강 Phase D2 (retro #27 codex 리뷰 반영, 8건) | PASS | A7a/A8a/A9a/A10a Boot-only 인버트; A9b properties 비인용 `include=*` 탐지; A9d `probability:` 강제; A10b `=== [AS` 앵커·A10c bash 주석 앵커 교체 |
| 2026-04-23 | §A 보강 Phase D3 (codex low 5건 + known-limitation 주석 3건) | PASS | A7d `chunk\s*(` whitespace; A8b/A10d FQCN 대체; A8d `@TimeToLive`/`time-to-live`; A10e `handleAsync`; A7b/A7c/A8c/A9c 구조적 한계 주석 |

### 자기참조 분석 세부 (허용 맥락 확인)

| 스킬 | 심볼 | 등장 위치 | 맥락 | 판정 |
|------|------|-----------|------|------|
| spring-principles | `@Autowired` | di.md:44,48 / anti-patterns.md:11 / constructor-injection.md:9,12 | `## 4) 금지 패턴` / `## 1) 필드 주입` 하위 Before 블록 | PASS |
| spring-principles | `public void setStatus` | rich-domain.md:18 | `## 2) Entity에 행위 부여` Anemic 안티패턴 Before 블록 | PASS |
| spring-principles | `public void setOrderRepository` | di.md:49 | `## 4) 금지 패턴` setter 주입 Before 블록 | PASS |
| spring-web | `@ExceptionHandler` | exception-handling.md:17,34,43,52,61 | `@RestControllerAdvice` 클래스 내부 — 정상 패턴 | PASS |
| spring-persistence | `@Transactional` line 102 | SKILL.md | `MemberService.register()` — Service 계층 정상 사용 | PASS |
| spring-security | `addCorsMappings` | cors.md:11 | "적용되지 않는다" 금지 설명 맥락 | PASS |
| spring-init | `1.20.3`, `1.6.3` | gradle-conventions.md:71,72 | testcontainers·mapstruct 버전 카탈로그 예시 — 라이브러리 버전 허용 | PASS |
| spring-async | `SimpleAsyncTaskExecutor` | SKILL.md:144 | `echo "=== [AS1] SimpleAsyncTaskExecutor / 비관리 스레드 ==="` — grep 명령 레이블 echo 라인 | PASS |
| spring-async | `new Thread(` | SKILL.md:142 | `# new Thread( — 원시 스레드 생성; Executors.newCachedThreadPool — 무한 스레드풀` — bash 주석 설명 맥락 | PASS |

---

## 최종 판정

**§A 확장 (38개 체크) + §B 2차 회전 (4개 스킬) 전부 PASS — 자기참조 위반 없음.**

retro #22 기준 21개 규칙에 Phase B/C 4개 신규 스킬(batch/cache/observability/async) 17개 규칙을 추가해
38개로 확장했다. 모든 규칙에서 SKILL 문서가 자신이 강제하는 패턴을 예시 코드에서 위반하지 않음을 확인했다.
