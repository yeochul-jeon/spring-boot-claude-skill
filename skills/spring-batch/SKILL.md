---
name: spring-batch
description: Use when implementing batch processing with Spring Batch.
  Trigger on "배치", "대량 처리", "Batch Job", "ItemReader", "ItemWriter",
  "스케줄 실행", "청크 처리". Enforces Job/Step separation, chunk-oriented
  processing, idempotent jobs, and separate JobRepository DataSource.
  Always asks chunk size and restart strategy before implementing.
---

# Spring Batch

Spring Batch 기반 배치 처리의 표준 패턴.
Job/Step 분리 → Chunk 설계 → 재시작 전략을 순서대로 확정하며,
코드 작성 완료 후 `spring-principles` 체크리스트로 자가 검증한다.

## 절대 원칙

1. **Job과 Step은 분리한다.** 비즈니스 로직은 Step(ItemReader/Processor/Writer)에, 흐름 제어는 Job에 둔다.
2. **Chunk 지향 처리를 기본으로 한다.** Tasklet은 DB 참조 없는 단순 파일 이동·알림에만 허용.
3. **Job은 멱등해야 한다.** 동일 파라미터로 재실행해도 데이터 중복이 없어야 한다.
4. **JobRepository DataSource를 애플리케이션 DataSource와 분리한다.** 배치 메타테이블과 도메인 테이블이 같은 스키마를 공유하면 장애 시 격리가 안 된다.

## 워크플로우

### 1. 의존성 추가

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-batch")
    testImplementation("org.springframework.batch:spring-batch-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:mysql")
}
```

> Spring Batch 버전은 Spring Boot BOM이 관리한다. 버전 숫자를 직접 쓰지 않는다.

### 2. Job / Step 설계

`references/job-design.md` 참조.

```java
@Configuration
@RequiredArgsConstructor
public class MemberExportJobConfig {

    private final JobRepository jobRepository;
    private final PlatformTransactionManager transactionManager;

    @Bean
    public Job memberExportJob(Step memberExportStep) {
        return new JobBuilder("memberExportJob", jobRepository)
            .start(memberExportStep)
            .build();
    }

    @Bean
    public Step memberExportStep(
        ItemReader<Member> reader,
        ItemProcessor<Member, MemberExportDto> processor,
        ItemWriter<MemberExportDto> writer
    ) {
        return new StepBuilder("memberExportStep", jobRepository)
            .<Member, MemberExportDto>chunk(100, transactionManager)
            .reader(reader)
            .processor(processor)
            .writer(writer)
            .build();
    }
}
```

### 3. Chunk 처리 구현

`references/chunk-processing.md` 참조.

- `ItemReader`: DB → `JdbcCursorItemReader` / `JpaPagingItemReader`
- `ItemProcessor`: 도메인 변환·필터링 (단일 책임)
- `ItemWriter`: `JdbcBatchItemWriter` / 외부 API 호출

### 4. 재시작 / 오류 처리

`references/restartability.md` 참조.

- `faultTolerant().skip(Exception.class).skipLimit(10)` — 허용 오류
- `retry(TransientException.class).retryLimit(3)` — 일시적 오류 재시도
- `JobParameters`에 타임스탬프 포함 → 새 JobInstance 생성
- 멱등성 보장: UPSERT 또는 처리 여부 플래그 필드 활용

### 5. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] Job/Step 책임 분리 — 비즈니스 로직이 ItemProcessor에 있음
- [ ] Chunk size가 명시적으로 설정됨 (default 값 그대로 사용 금지)
- [ ] Job 멱등성 확보 — 재실행 시 중복 데이터 없음
- [ ] JobRepository DataSource가 애플리케이션 DataSource와 분리됨
- [ ] `faultTolerant()` skip/retry 정책이 업무 요건에 맞게 설정됨
- [ ] `@Transactional`은 Spring Batch 내부가 아닌 Step 경계에서 관리됨
- [ ] Job 파라미터에 재실행 구분자 포함 (타임스탬프 or 식별자)
- [ ] `spring-principles` 체크리스트 전 항목 통과

## grep 자동 검증 패턴

`<SRC>` 는 프로젝트의 `src/main/java` 절대 경로.

```bash
# B1: chunk size 미설정 — chunk() 호출 없음 (0건이면 수동 확인 필요)
echo "=== [B1] chunk size 설정 ==="
grep -rn "\.chunk(" <SRC>/ || echo "WARN: chunk() 호출 없음 — Tasklet 전용 여부 확인"

# B2: @Transactional이 Batch Step 클래스에 직접 선언 (0건이어야 PASS)
echo "=== [B2] Step 클래스 @Transactional ==="
grep -rn "@Transactional" <SRC>/*/batch/step/ <SRC>/*/batch/reader/ <SRC>/*/batch/writer/ 2>/dev/null || echo "PASS"

# B3: JobRepository 별도 DataSource 설정 (1건 이상이어야 PASS)
echo "=== [B3] JobRepository DataSource 분리 ==="
grep -rn "JobRepository\|BatchDataSource\|batchDataSource" <SRC>/../resources/ <SRC>/ 2>/dev/null | head -5
echo "(위 결과 1건 이상 → PASS)"

# B4: faultTolerant 설정 확인
echo "=== [B4] faultTolerant 설정 ==="
grep -rn "faultTolerant\|skipLimit\|retryLimit" <SRC>/ | head -5
```

## references/ 목록

| 파일 | 설명 |
|---|---|
| `job-design.md` | Job/Step 분리 원칙, JobBuilder/StepBuilder, 흐름 제어 (Flow·Decision) |
| `chunk-processing.md` | ItemReader/Processor/Writer 구현 패턴, JdbcCursorItemReader vs JpaPagingItemReader |
| `restartability.md` | 멱등성 설계, skip/retry 정책, JobParameters 전략, 재시작 시나리오 |
