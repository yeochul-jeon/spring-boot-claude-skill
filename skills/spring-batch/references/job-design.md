# Job 설계 — Spring Batch

## 1) Job / Step 책임 분리

```
Job  →  Flow (조건 분기) →  Step  →  ItemReader
                                  →  ItemProcessor
                                  →  ItemWriter
```

- **Job**: 전체 배치 흐름(실행 순서, 조건 분기)만 담당
- **Step**: 단일 처리 단위 — 한 Step이 한 가지 책임
- **ItemProcessor**: 도메인 변환·필터링만. DB 접근 금지 — 필요하면 Step을 분리

## 2) JobBuilder / StepBuilder

```java
@Bean
public Job sampleJob(Step step1, Step step2) {
    return new JobBuilder("sampleJob", jobRepository)
        .start(step1)
        .on("FAILED").to(step2)            // 조건 분기
        .from(step1).on("*").end()
        .end()
        .build();
}
```

`on("FAILED")` / `on("COMPLETED")` / `on("*")` 로 ExitStatus 기반 분기 가능.

## 3) 멱등성 설계

| 방법 | 설명 |
|------|------|
| UPSERT | `INSERT ... ON DUPLICATE KEY UPDATE` 또는 JPA `saveOrUpdate` |
| 처리 플래그 | `processed_at` 컬럼으로 이미 처리된 행 스킵 |
| 타임스탬프 파라미터 | `JobParameters`에 `run.id` 또는 타임스탬프 포함 → 새 JobInstance |

## 4) JobParameters 전략

```java
JobParameters params = new JobParametersBuilder()
    .addString("inputFile", "/data/members.csv")
    .addLocalDateTime("runAt", LocalDateTime.now())   // 재실행 구분자
    .toJobParameters();
```

동일한 JobParameters 로는 이미 COMPLETED 된 JobInstance 를 재실행할 수 없다.
재실행이 필요하면 파라미터에 변경 요소를 추가한다.

## 5) JobRepository DataSource 분리

```java
@Configuration
public class BatchInfraConfig {

    @Bean
    @Primary
    public DataSource appDataSource() { ... }      // 애플리케이션 DataSource

    @Bean
    @BatchDataSource
    public DataSource batchDataSource() { ... }    // 배치 메타 DataSource

    @Bean
    public PlatformTransactionManager batchTransactionManager(
        @BatchDataSource DataSource batchDataSource
    ) {
        return new DataSourceTransactionManager(batchDataSource);
    }
}
```
