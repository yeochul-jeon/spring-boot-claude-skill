---
name: spring-async
description: Use when implementing asynchronous processing in Spring Boot.
  Trigger on "비동기", "@Async", "CompletableFuture", "@Scheduled", "스레드풀",
  "ThreadPoolTaskExecutor", "virtual threads". Enforces explicit thread pool
  configuration (SimpleAsyncTaskExecutor banned), proper exception propagation,
  and @Scheduled overlap prevention.
---

# Spring Async

Spring Boot 비동기 처리의 표준 패턴.
스레드풀 설계 → @Async / @Scheduled 구성 → 예외 처리를 순서대로 확정하며,
코드 작성 완료 후 `spring-principles` 체크리스트로 자가 검증한다.

## 절대 원칙

1. **`SimpleAsyncTaskExecutor`를 사용하지 않는다.** 이 구현체는 요청마다 새 스레드를 생성해 스레드 폭증으로 OOM이 발생한다. 반드시 `ThreadPoolTaskExecutor`(또는 virtual threads)를 명시적으로 등록한다.
2. **`@Async` 메서드의 반환 타입은 `void` 또는 `CompletableFuture<T>`만 허용한다.** 다른 반환 타입은 비동기 프록시가 적용되지 않는다.
3. **`CompletableFuture`에서 예외를 명시적으로 처리한다.** `thenApply` 체인에서 발생한 예외는 기본적으로 무시된다 — `exceptionally` 또는 `handle`로 처리한다.
4. **`@Scheduled` 작업은 겹침을 방지한다.** 이전 실행이 끝나기 전에 다음 실행이 시작되면 데이터 경쟁이 발생한다 — `@SchedulerLock` 또는 `ShedLock` 적용.

## 워크플로우

### 1. 의존성 추가

```kotlin
dependencies {
    // @Async / @Scheduled 는 spring-boot-starter 포함
    // ShedLock — @Scheduled 분산 잠금 (선택)
    implementation("net.javacrumbs.shedlock:shedlock-spring:${latestVersion}")
    implementation("net.javacrumbs.shedlock:shedlock-provider-jdbc-template:${latestVersion}")
}
```

> ShedLock 버전은 Maven Central에서 최신을 확인한다.

### 2. 스레드풀 설정

`references/thread-pool.md` 참조.

```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(16);
        executor.setQueueCapacity(500);
        executor.setThreadNamePrefix("async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return new SimpleAsyncUncaughtExceptionHandler();
    }
}
```

**Java 21 Virtual Threads (선택)**

```java
@Bean
public Executor virtualThreadExecutor() {
    return Executors.newVirtualThreadPerTaskExecutor();
}
```

> Virtual threads는 I/O 집약 작업에 적합. CPU 집약 작업에는 전통 ThreadPool 유지.

### 3. @Async 메서드 작성

`references/completable-future.md` 참조.

```java
@Service
@RequiredArgsConstructor
public class NotificationService {

    @Async
    public CompletableFuture<Void> sendEmail(String to, String subject) {
        // 메일 발송 로직
        return CompletableFuture.completedFuture(null);
    }
}
```

예외 처리:

```java
notificationService.sendEmail(email, subject)
    .exceptionally(ex -> {
        log.error("이메일 발송 실패: {}", ex.getMessage());
        return null;
    });
```

### 4. @Scheduled 겹침 방지

`references/scheduling.md` 참조.

```java
@Component
@RequiredArgsConstructor
public class DataSyncScheduler {

    @Scheduled(cron = "0 0 2 * * *")
    @SchedulerLock(name = "dataSyncJob", lockAtLeastFor = "PT5M", lockAtMostFor = "PT30M")
    public void syncData() {
        // 배치 동기화 로직
    }
}
```

### 5. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] `SimpleAsyncTaskExecutor` 사용 없음 — `ThreadPoolTaskExecutor` 또는 virtual threads 명시
- [ ] `@EnableAsync` 설정 완료
- [ ] `@Async` 메서드 반환 타입이 `void` 또는 `CompletableFuture<T>`
- [ ] `CompletableFuture` 체인에 `exceptionally` 또는 `handle` 예외 처리 존재
- [ ] `@Scheduled` 작업에 `@SchedulerLock` 또는 단일 인스턴스 보장 설정
- [ ] 스레드풀 core/max/queue 크기가 업무 요건에 맞게 명시됨
- [ ] `RejectedExecutionHandler` 정책 설정 (기본 AbortPolicy 유지 시 의도적 결정)
- [ ] `spring-principles` 체크리스트 전 항목 통과

## grep 자동 검증 패턴

`<SRC>` 는 프로젝트의 `src/main/java` 절대 경로.

```bash
# AS1: SimpleAsyncTaskExecutor 또는 비관리 스레드 직접 생성 (0건이어야 PASS)
# new Thread( — 원시 스레드 생성; Executors.newCachedThreadPool — 무한 스레드풀
# 주의: head -3 은 빈 입력에서도 exit 0 → UNSAFE 변수로 출력 여부를 판별해야 함
echo "=== [AS1] SimpleAsyncTaskExecutor / 비관리 스레드 ==="
grep -rn "SimpleAsyncTaskExecutor" <SRC>/ | grep -v "//\|import\|grep" || echo "PASS"
UNSAFE=$(grep -rn "new Thread(\|Executors\.newCachedThreadPool\|Executors\.newSingleThreadExecutor" <SRC>/ \
  | grep -v "//\|import\|ThreadPoolTaskExecutor\|ThreadPoolExecutor")
[ -n "$UNSAFE" ] && echo "$UNSAFE" && echo "WARN: 비관리 스레드 직접 생성 — ThreadPoolTaskExecutor 또는 virtual threads 사용 권장" || echo "PASS"

# AS2: @EnableAsync 설정 (1건 이상이어야 PASS)
echo "=== [AS2] @EnableAsync ==="
grep -rn "@EnableAsync" <SRC>/ || echo "FAIL: @EnableAsync 없음"

# AS3: @Async 메서드 반환 타입 확인 (void/CompletableFuture 외 타입 경고)
# 주의: @Async 뒤에 다른 어노테이션이 오면 -A1 이 해당 어노테이션을 반환 타입으로 오인할 수 있음
# → 출력이 있으면 반환 타입인지 어노테이션인지 수동 확인
echo "=== [AS3] @Async 반환 타입 ==="
grep -rn -A1 "@Async" <SRC>/ | grep -v "@Async\|//\|#\|--" | grep -v "void\|CompletableFuture" | head -5
echo "MANUAL: 위 결과가 반환 타입인지 중간 어노테이션인지 수동 확인 필요"

# AS4: @Scheduled 존재 시 잠금 설정 확인
echo "=== [AS4] @Scheduled 잠금 ==="
SCHED_COUNT=$(grep -rn "@Scheduled" <SRC>/ | grep -v "//\|import" | wc -l | tr -d ' ')
LOCK_COUNT=$(grep -rn "@SchedulerLock\|ShedLock" <SRC>/ | grep -v "//\|import" | wc -l | tr -d ' ')
echo "@Scheduled: $SCHED_COUNT, @SchedulerLock: $LOCK_COUNT"
[ "$SCHED_COUNT" -gt 0 ] && [ "$LOCK_COUNT" -eq 0 ] && echo "WARN: @Scheduled 있으나 잠금 없음 — fixedDelay 단일 인스턴스인 경우는 허용 (수동 확인)"

# AS5: CompletableFuture 예외 처리 (1건 이상이어야 PASS — @Async 호출 측)
echo "=== [AS5] CompletableFuture 예외 처리 ==="
grep -rn "exceptionally\|\.handle(" <SRC>/ | grep -v "//\|import" | head -5
echo "MANUAL: @Async 메서드 호출마다 exceptionally 또는 handle 체인 여부 수동 확인"
```

## references/ 목록

| 파일 | 설명 |
|---|---|
| `thread-pool.md` | ThreadPoolTaskExecutor 설정, virtual threads 선택 기준, RejectedExecutionHandler 정책 |
| `completable-future.md` | @Async 패턴, CompletableFuture 조합(allOf/anyOf), 예외 전파, 타임아웃 설정 |
| `scheduling.md` | @Scheduled cron/fixedDelay/fixedRate, ShedLock 분산 잠금, @EnableScheduling, 멀티 인스턴스 주의사항 |
