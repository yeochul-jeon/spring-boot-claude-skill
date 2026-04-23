# Regression Test #26 — spring-async 체크리스트 empirical 검증

날짜 초안: 2026-04-23

---

## 목적

`spring-async` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro26-async   # BASELINE
SRC=$SANDBOX/src/main/java

SANDBOX_V2=/Users/cjenm/github/test-retro26-async-v2  # 2차 회전
SRC_V2=$SANDBOX_V2/src/main/java
```

시나리오: "회원 가입 완료 후 `NotificationService.sendWelcomeEmail` 을 `@Async` 로 호출.
매일 02:00 에 `DataSyncScheduler.syncInactiveMembers` 가 동작 (멀티 인스턴스 환경, ShedLock 적용).
ThreadPoolTaskExecutor: core=4 / max=16 / queue=500 / CallerRunsPolicy."

---

## §2 grep 자동 검증

아래 명령은 BASELINE(`$SRC`)과 2차 회전(`$SRC_V2`) 각각에 대해 `SRC` 를 치환해 실행한다.

```bash
# AS1: SimpleAsyncTaskExecutor 또는 비관리 스레드 직접 생성 (0건이어야 PASS)
# 주의: head -3 은 빈 입력에도 exit 0 — UNSAFE 변수로 출력 여부 판별
echo "=== [AS1] SimpleAsyncTaskExecutor / 비관리 스레드 ==="
grep -rn "SimpleAsyncTaskExecutor" $SRC/ | grep -v "//\|import\|grep" || echo "PASS"
UNSAFE=$(grep -rn "new Thread(\|Executors\.newCachedThreadPool\|Executors\.newSingleThreadExecutor" $SRC/ \
  | grep -v "//\|import\|ThreadPoolTaskExecutor\|ThreadPoolExecutor")
[ -n "$UNSAFE" ] && echo "$UNSAFE" && echo "WARN: 비관리 스레드 직접 생성 — ThreadPoolTaskExecutor 또는 virtual threads 사용 권장" || echo "PASS"

# AS2: @EnableAsync 설정 (1건 이상이어야 PASS)
echo "=== [AS2] @EnableAsync ==="
grep -rn "@EnableAsync" $SRC/ || echo "FAIL: @EnableAsync 없음"

# AS3: @Async 메서드 반환 타입 확인 (void/CompletableFuture 외 타입 경고)
# 주의: @Async 뒤에 다른 어노테이션이 오면 -A1 이 해당 어노테이션을 반환 타입으로 오인 — 수동 확인
echo "=== [AS3] @Async 반환 타입 ==="
grep -rn -A1 "@Async" $SRC/ | grep -v "@Async\|//\|#\|--" | grep -v "void\|CompletableFuture" | head -5
echo "MANUAL: 위 결과가 반환 타입인지 중간 어노테이션인지 수동 확인 필요"

# AS4: @Scheduled 존재 시 잠금 설정 확인
echo "=== [AS4] @Scheduled 잠금 ==="
SCHED_COUNT=$(grep -rn "@Scheduled" $SRC/ | grep -v "//\|import" | wc -l | tr -d ' ')
LOCK_COUNT=$(grep -rn "@SchedulerLock\|ShedLock" $SRC/ | grep -v "//\|import" | wc -l | tr -d ' ')
echo "@Scheduled: $SCHED_COUNT, @SchedulerLock: $LOCK_COUNT"
[ "$SCHED_COUNT" -gt 0 ] && [ "$LOCK_COUNT" -eq 0 ] && echo "WARN: @Scheduled 있으나 잠금 없음 — fixedDelay 단일 인스턴스인 경우는 허용 (수동 확인)"

# AS5: CompletableFuture 예외 처리 (1건 이상이어야 PASS — @Async 호출 측)
echo "=== [AS5] CompletableFuture 예외 처리 ==="
grep -rn "exceptionally\|\.handle(" $SRC/ | grep -v "//\|import" | head -5
echo "MANUAL: @Async 메서드 호출마다 exceptionally 또는 handle 체인 여부 수동 확인"
```

---

## §3 수동 체크리스트

```
스레드풀 설계
- [ ] ThreadPoolTaskExecutor core/max/queue/threadNamePrefix 모두 명시됨
- [ ] RejectedExecutionHandler 정책 설정됨 (CallerRunsPolicy 또는 의도적 AbortPolicy)
- [ ] SimpleAsyncTaskExecutor 없음, new Thread()/newCachedThreadPool() 없음

@Async / CompletableFuture
- [ ] @EnableAsync 설정 완료
- [ ] @Async 메서드 반환 타입이 void 또는 CompletableFuture<T>
- [ ] CompletableFuture 호출 측에 exceptionally 또는 handle 예외 처리 존재
- [ ] @Async 메서드가 같은 클래스 내부에서 호출되지 않음 (프록시 우회 방지)

@Scheduled / ShedLock
- [ ] @Scheduled 작업에 @SchedulerLock 적용 (lockAtLeastFor + lockAtMostFor 명시)
- [ ] @EnableSchedulerLock 설정 완료
- [ ] ShedLock 저장소(JDBC/Redis 등) Bean 등록됨

spring-principles
- [ ] 생성자 주입 100% (@Autowired 필드 없음)
- [ ] spring-principles 체크리스트 전 항목 통과
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-23 | BASELINE (welcomeEmail+dataSyncScheduler) | PASS (탐지 공백 3건) | AS1~AS4 실제 결함 0건; 아래 탐지 공백 수집 |
| 2026-04-23 | 2차 회전 (SKILL.md 로드 후 재생성) | PASS | AS1~AS5 전부 PASS; @Async("taskExecutor") 명시, exceptionally 포함 |

### 2026-04-23 탐지 공백 목록

| 코드 | 탐지 공백 | 분류 |
|------|-----------|------|
| AS5_EXCEPTION | v0.1 에 `exceptionally`/`handle` 검사 없음 — `@Async` 호출 측에서 예외 처리 누락 시 미탐지 | 탐지 공백 → AS5 신규 grep 추가 |
| AS1_DIRECT_THREAD | v0.1 AS1: `SimpleAsyncTaskExecutor` 만 탐지 — `new Thread(` / `Executors.newCachedThreadPool()` 직접 스레드 생성 미탐지 | 탐지 공백 → `UNSAFE` 변수 패턴으로 확장 |
| AS3_MULTILINE | v0.1 AS3: `-A1` 기법은 `@Async` 뒤 어노테이션이 끼면 반환 타입 대신 어노테이션을 포착 — false-positive 가능 | 탐지 공백 (latent) → MANUAL 수동 확인 격상 |
| AS1_HEAD_BUG | `head -3 && echo "WARN"` 패턴 — `head` 빈 입력에서 exit 0 반환으로 WARN 항상 출력 | 구현 버그 → `UNSAFE` 변수로 교체 |

### 수정된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `skills/spring-async/SKILL.md` | AS1 확장: `new Thread(`/`Executors.newCachedThreadPool` + `UNSAFE` 변수 패턴; AS3: MANUAL 수동 확인 격상; AS4: `fixedDelay` 단일 인스턴스 허용 주석; AS5 신규: `exceptionally`/`handle` grep 추가 |

### 2차 회전 관찰

SKILL.md 로드 후 생성 코드에서 추가된 사항:
- `@Async("taskExecutor")` — 명시적으로 실행자 이름 지정
- `MemberService.register()` 에 `exceptionally` 에러 처리 포함
- AS1~AS5 전부 PASS

---

## §A 자기참조 검증

```bash
SKILLS=/Users/cjenm/github/spring-boot-claude-skill/skills
# 버전 하드코딩 없음
grep -rEn '[0-9]+\.[0-9]+\.[0-9]+' $SKILLS/spring-async/ || echo "PASS"

# SimpleAsyncTaskExecutor 자기참조 위반 없음 (금지 설명 맥락 허용)
grep -rn "SimpleAsyncTaskExecutor" $SKILLS/spring-async/ \
  | grep -v "절대 원칙\|사용하지 않는다\|사용 금지\|# AS1\|grep -rn\|- \[ \]\|banned\|// 금지" || echo "PASS"
```

→ 버전 하드코딩 없음 (PASS) / 자기참조 위반 없음 (PASS — 모두 금지 설명 맥락)
