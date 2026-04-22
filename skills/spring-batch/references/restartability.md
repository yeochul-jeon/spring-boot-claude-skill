# 재시작 / 오류 처리 — Spring Batch

## 1) FaultTolerant — Skip / Retry

```java
@Bean
public Step tolerantStep(
    ItemReader<Member> reader,
    ItemProcessor<Member, MemberExportDto> processor,
    ItemWriter<MemberExportDto> writer
) {
    return new StepBuilder("tolerantStep", jobRepository)
        .<Member, MemberExportDto>chunk(100, transactionManager)
        .reader(reader)
        .processor(processor)
        .writer(writer)
        .faultTolerant()
        .skip(DataAccessException.class)    // 이 예외는 스킵
        .skipLimit(10)                      // 최대 10건 스킵 허용
        .retry(TransientDataAccessException.class)
        .retryLimit(3)                      // 최대 3회 재시도
        .build();
}
```

| 옵션 | 설명 |
|------|------|
| `skip` | 해당 예외 발생 시 아이템 건너뜀 |
| `skipLimit` | 누적 skip 허용 최대치; 초과 시 Job FAIL |
| `retry` | 해당 예외 발생 시 청크 재시도 |
| `retryLimit` | 아이템당 재시도 횟수 |

## 2) SkipListener — 스킵 아이템 추적

```java
public class MemberSkipListener implements SkipListener<Member, MemberExportDto> {

    @Override
    public void onSkipInProcess(Member item, Throwable t) {
        log.warn("skip in process: memberId={}, reason={}", item.getId(), t.getMessage());
    }
}
```

Step에 `.listener(skipListener)` 로 등록.

## 3) 재시작 시나리오

| 상황 | 동작 |
|------|------|
| 동일 JobParameters로 재실행 | 기존 JobInstance에서 FAILED Step부터 재시작 |
| 새 JobParameters로 재실행 | 새 JobInstance 생성 — 처음부터 시작 |
| `@NonRestartable` Step | 재시작 시 해당 Step은 건너뜀 |

```java
// 재실행 허용 Step
new StepBuilder("step1", jobRepository)
    .allowStartIfComplete(true)   // COMPLETED 상태라도 재실행
    ...
```

## 4) 멱등성 패턴 예시

```sql
-- UPSERT (MySQL)
INSERT INTO member_export (member_id, email, exported_at)
VALUES (?, ?, NOW())
ON DUPLICATE KEY UPDATE
    email = VALUES(email),
    exported_at = NOW();
```

```java
// 처리 여부 플래그
member.getExportedAt() != null → skip (이미 처리됨)
```

## 5) 모니터링 포인트

- `BATCH_JOB_INSTANCE`, `BATCH_JOB_EXECUTION`, `BATCH_STEP_EXECUTION` 테이블 — Spring Batch 메타
- `READ_COUNT`, `WRITE_COUNT`, `SKIP_COUNT`, `ROLLBACK_COUNT` — Step 실행 통계
- `/actuator/health` → `batchDataSource` health indicator 포함 권장
