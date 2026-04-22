# @Scheduled + ShedLock

## 1) @Scheduled 기본

```java
@Configuration
@EnableScheduling
public class SchedulingConfig { }

@Component
public class DataSyncScheduler {

    @Scheduled(cron = "0 0 2 * * *")           // 매일 오전 2시
    public void syncData() { ... }

    @Scheduled(fixedDelay = 60_000)             // 이전 실행 완료 후 60초
    public void processQueue() { ... }

    @Scheduled(fixedRate = 60_000)              // 시작 기준 60초마다 (겹침 가능)
    public void checkHealth() { ... }
}
```

`fixedRate` 는 이전 실행이 끝나기 전에 다음 실행이 시작될 수 있다. 겹침이 문제가 되는 작업에는 `fixedDelay` 사용.

## 2) ShedLock — 분산 잠금

다중 인스턴스 환경에서 단 하나의 인스턴스만 실행되도록 보장.

```kotlin
// build.gradle.kts
implementation("net.javacrumbs.shedlock:shedlock-spring:${latestVersion}")
implementation("net.javacrumbs.shedlock:shedlock-provider-jdbc-template:${latestVersion}")
```

```java
@Configuration
@EnableSchedulerLock(defaultLockAtMostFor = "PT10M")
@RequiredArgsConstructor
public class ShedLockConfig {

    @Bean
    public LockProvider lockProvider(DataSource dataSource) {
        return new JdbcTemplateLockProvider(
            JdbcTemplateLockProvider.Configuration.builder()
                .withJdbcTemplate(new JdbcTemplate(dataSource))
                .usingDbTime()
                .build()
        );
    }
}
```

```java
@Component
@RequiredArgsConstructor
public class DataSyncScheduler {

    @Scheduled(cron = "0 0 2 * * *")
    @SchedulerLock(
        name = "dataSyncJob",
        lockAtLeastFor = "PT5M",    // 빠른 완료 후에도 최소 5분 잠금 유지
        lockAtMostFor = "PT30M"     // 인스턴스 비정상 종료 시 30분 후 자동 해제
    )
    public void syncData() { ... }
}
```

ShedLock DDL (`shedlock` 테이블 생성):

```sql
CREATE TABLE shedlock (
    name        VARCHAR(64) NOT NULL,
    lock_until  TIMESTAMP(3) NOT NULL,
    locked_at   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    locked_by   VARCHAR(255) NOT NULL,
    PRIMARY KEY (name)
);
```

## 3) lockAtLeastFor vs lockAtMostFor

| 파라미터 | 설명 |
|---------|------|
| `lockAtLeastFor` | 실행이 빠르게 완료돼도 이 시간만큼 잠금 유지 (중복 실행 방지) |
| `lockAtMostFor` | 인스턴스 비정상 종료 시 이 시간 후 잠금 자동 해제 (deadlock 방지) |

`lockAtLeastFor` ≤ 예상 실행 시간, `lockAtMostFor` ≥ 예상 실행 시간 + 여유 시간.

## 4) 단일 인스턴스 환경 (@Scheduled 겹침 방지)

ShedLock 없이 같은 JVM 내에서 겹침 방지:

```java
@Scheduled(fixedDelay = 60_000)   // fixedRate 대신 fixedDelay 사용
@ScheduledLock                      // ShedLock의 in-memory 잠금
public void processQueue() { ... }
```

또는 `TaskScheduler`에 단일 스레드 풀 사용:

```java
@Bean
public TaskScheduler scheduledTaskScheduler() {
    ThreadPoolTaskScheduler scheduler = new ThreadPoolTaskScheduler();
    scheduler.setPoolSize(1);    // 동시 실행 방지
    scheduler.setThreadNamePrefix("scheduler-");
    return scheduler;
}
```

## 5) @Scheduled 테스트

```java
// Spring 컨텍스트에서 스케줄러 비활성화
@SpringBootTest
@MockBean(SchedulingConfigurer.class)   // 스케줄러 비활성
class OrderServiceTest { ... }

// 또는 프로파일로 제외
@ConditionalOnProperty(name = "scheduling.enabled", havingValue = "true", matchIfMissing = true)
@Component
public class DataSyncScheduler { ... }
```
