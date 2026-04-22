# Chunk 처리 — ItemReader / Processor / Writer

## 1) Chunk 지향 처리 흐름

```
read() → read() → ... (chunk size 만큼)
→ [process() → process() → ...]
→ write([chunk]) → commit
```

청크 단위로 트랜잭션 커밋. chunk size 가 너무 크면 메모리 압박, 너무 작으면 트랜잭션 오버헤드.
**일반 권장값: 100~1000** — 실측 튜닝 필요.

## 2) ItemReader 선택

| 구현체 | 특징 | 적합 |
|--------|------|------|
| `JdbcCursorItemReader` | DB 커서 유지, 메모리 효율 | 대용량 단일 테이블 |
| `JpaPagingItemReader` | 페이지 단위 쿼리, EntityManager 사용 | JPA 연관관계 있는 조회 |
| `FlatFileItemReader` | CSV/TSV 파일 | 파일 기반 배치 |
| `StaxEventItemReader` | XML 스트리밍 | XML 대용량 처리 |

```java
@Bean
@StepScope
public JpaPagingItemReader<Member> memberReader(EntityManagerFactory emf) {
    return new JpaPagingItemReaderBuilder<Member>()
        .name("memberReader")
        .entityManagerFactory(emf)
        .queryString("SELECT m FROM Member m WHERE m.status = :status")
        .parameterValues(Map.of("status", MemberStatus.ACTIVE))
        .pageSize(100)
        .build();
}
```

> `@StepScope` — Step 실행마다 새 Bean 생성, JobParameters 주입 가능.

## 3) ItemProcessor

단일 변환/필터 책임. null 반환 시 해당 아이템은 write 단계에서 제외됨.

```java
@Bean
@StepScope
public ItemProcessor<Member, MemberExportDto> memberProcessor() {
    return member -> {
        if (member.isDeleted()) return null;   // null → write 제외
        return MemberExportDto.from(member);
    };
}
```

## 4) ItemWriter

```java
@Bean
public JdbcBatchItemWriter<MemberExportDto> memberWriter(DataSource dataSource) {
    return new JdbcBatchItemWriterBuilder<MemberExportDto>()
        .dataSource(dataSource)
        .sql("INSERT INTO member_export (member_id, email) VALUES (:memberId, :email)")
        .beanMapped()
        .build();
}
```

## 5) Chunk Size 결정 가이드

| 조건 | 권장 chunk size |
|------|-----------------|
| 단순 행 변환 (CPU 중심) | 500~1000 |
| 외부 API 호출 포함 | 10~50 (API rate limit 고려) |
| 대용량 파일 쓰기 | 100~500 |
| Retry/Skip 빈번 예상 | 50~200 (롤백 범위 최소화) |
