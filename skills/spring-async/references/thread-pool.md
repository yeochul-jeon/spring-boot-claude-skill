# ThreadPoolTaskExecutor 설정

## 1) 기본 설정

```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);          // 유휴 스레드 최소 유지
        executor.setMaxPoolSize(16);          // 최대 스레드 수
        executor.setQueueCapacity(500);       // 큐 대기 허용 건수
        executor.setThreadNamePrefix("async-worker-");
        executor.setRejectedExecutionHandler(
            new ThreadPoolExecutor.CallerRunsPolicy()   // 큐 초과 시 호출자 스레드에서 실행
        );
        executor.initialize();
        return executor;
    }

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return (ex, method, params) ->
            log.error("Async exception in {}: {}", method.getName(), ex.getMessage(), ex);
    }
}
```

> `SimpleAsyncTaskExecutor` 는 요청마다 새 스레드를 생성한다 — 절대 사용 금지. // 금지

## 2) 파라미터 튜닝 기준

| 파라미터 | 공식 | 설명 |
|---------|------|------|
| `corePoolSize` | CPU 코어 수 또는 측정값 | I/O 집약 작업은 코어 수 × 2~4 |
| `maxPoolSize` | corePoolSize × 2~4 | 피크 트래픽 처리 |
| `queueCapacity` | 평균 TPS × 허용 대기 시간(s) | 메모리 예산 고려 |

**corePoolSize 이상 요청이 오면 큐에 적재 → 큐 초과 시 maxPoolSize까지 스레드 생성 → maxPool 초과 시 RejectedExecutionHandler 호출.**

## 3) 용도별 스레드풀 분리

```java
@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean(name = "emailExecutor")
    public Executor emailExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(200);
        executor.setThreadNamePrefix("email-");
        executor.initialize();
        return executor;
    }

    @Bean(name = "reportExecutor")
    public Executor reportExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("report-");
        executor.initialize();
        return executor;
    }
}
```

각 `@Async` 에 `@Async("emailExecutor")` 로 스레드풀 지정.

## 4) Java 21 Virtual Threads

I/O 집약 작업(DB, 외부 API, 파일)에 적합:

```java
@Bean(name = "virtualThreadExecutor")
public Executor virtualThreadExecutor() {
    return Executors.newVirtualThreadPerTaskExecutor();
}
```

- 플랫폼 스레드(OS 스레드) 고갈 문제 해결
- CPU 집약 작업(암호화, 이미지 변환)에는 전통 `ThreadPoolTaskExecutor` 유지
- Pinning 주의: `synchronized` 블록 안에서 I/O 차단 시 carrier thread 고정 발생

## 5) RejectedExecutionHandler 정책

| 정책 | 동작 | 사용 시점 |
|------|------|-----------|
| `CallerRunsPolicy` | 호출자 스레드에서 실행 | 요청 손실 허용 불가 |
| `AbortPolicy` (기본) | 예외 발생 | 즉각 오류 감지 필요 |
| `DiscardPolicy` | 요청 버림 | 손실 허용 로그 이벤트 |
| `DiscardOldestPolicy` | 가장 오래된 요청 버림 | 최신 요청 우선 |
