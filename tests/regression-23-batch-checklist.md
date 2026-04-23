# Regression Test #23 — spring-batch 체크리스트 empirical 검증

날짜 초안: 2026-04-23

---

## 목적

`spring-batch` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro23   # BASELINE
SRC=$SANDBOX/src/main/java

SANDBOX_V2=/Users/cjenm/github/test-retro23-batch-v2  # 2차 회전
SRC_V2=$SANDBOX_V2/src/main/java
```

시나리오: "회원 100만 건을 매일 새벽 CSV 로 내보내는 memberExportJob.
재실행 시 중복 없음, 최근 실패 skip 허용 10건."

---

## §2 grep 자동 검증

```bash
# B1: chunk size 미설정
# 주의: .<T,R>chunk(...) type witness 구문도 탐지하도록 chunk( 로 검색
echo "=== [B1] chunk size 설정 ==="
grep -rn "chunk(" $SRC/ | grep -v "//\|chunkSize\|CHUNK_SIZE\s*=" || echo "WARN: chunk() 없음 — Tasklet 전용 여부 확인"

# B2: @Transactional이 Batch Step 클래스에 직접 선언 (0건이어야 PASS)
echo "=== [B2] Step 클래스 @Transactional ==="
find "$SRC" \( -path "*/batch/step/*.java" -o -path "*/batch/reader/*.java" -o -path "*/batch/writer/*.java" \) -print0 2>/dev/null \
  | xargs -0 grep -ln "@Transactional" 2>/dev/null || echo "PASS"

# B3: JobRepository DataSource 분리 (1건 이상이어야 PASS)
# Spring Boot 4: @EnableJdbcJobRepository(dataSourceRef=...) 로 분리
# Spring Boot 3: @BatchDataSource 또는 DefaultBatchConfiguration 서브클래스로 분리
echo "=== [B3] JobRepository DataSource 분리 ==="
grep -rn "@BatchDataSource\|batchDataSource.*DataSource\|EnableJdbcJobRepository\|DefaultBatchConfiguration\|BatchDataSourceScriptDatabaseInitializer" \
  $SANDBOX/src/main/resources/ $SRC/ 2>/dev/null | head -5 \
  || echo "FAIL: 별도 BatchDataSource Bean 없음"

# B4: faultTolerant 설정 확인
echo "=== [B4] faultTolerant 설정 ==="
grep -rn "faultTolerant\|skipLimit\|retryLimit" $SRC/ | head -5
```

---

## §3 수동 체크리스트

```
Job / Step 구조
- [ ] Job/Step 책임 분리 — 비즈니스 로직이 ItemProcessor에 있음
- [ ] Chunk size가 명시적으로 설정됨 (default 값 그대로 사용 금지)
- [ ] Job 멱등성 확보 — 재실행 시 중복 데이터 없음 (UPSERT 또는 파라미터 구분)
- [ ] Job 파라미터에 재실행 구분자 포함 (타임스탬프 or 날짜 식별자)

DataSource
- [ ] JobRepository DataSource가 애플리케이션 DataSource와 분리됨
      Spring Boot 4: @EnableJdbcJobRepository(dataSourceRef="batchDataSource")
      Spring Boot 3: @BatchDataSource Bean 또는 DefaultBatchConfiguration 서브클래스

오류 처리
- [ ] faultTolerant() skip/retry 정책이 업무 요건에 맞게 설정됨
- [ ] @Transactional은 Spring Batch 내부가 아닌 Step 경계에서 관리됨
      (Step 클래스 / Reader / Writer에 @Transactional 직접 선언 금지)

spring-principles
- [ ] 생성자 주입 100% (@Autowired 필드 없음)
- [ ] 엔티티 직접 노출 없음 (ItemProcessor가 DTO로 변환)
- [ ] spring-principles 체크리스트 전 항목 통과
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-23 | BASELINE (맨세션, memberExportJob) | B1 false-negative, B3 false-positive | 결함 2건 — 아래 상세 |
| 2026-04-23 | 2차 회전 (SKILL.md 로드 후 재생성) | B1~B4 PASS, spring-principles PASS | 결함 0건 |

### 2026-04-23 BASELINE 결함 목록

| 코드 | 결함 | 분류 |
|------|------|------|
| B1_GREP | v0.1 패턴 `\.chunk(` 이 `.<Member, MemberExportDto>chunk(...)` type witness 구문에서 false-negative 반환 | 탐지 공백 — grep 패턴 수정 (`chunk(` + 금지어 filter로 교체) |
| B3_DS | BASELINE 코드에 별도 BatchDataSource Bean 없음; v0.1 B3 grep 은 `JobRepository` import 를 보고 false-PASS 반환 | 탐지 공백 — grep 패턴 강화 (`@BatchDataSource\|EnableJdbcJobRepository` 추가) + references/job-design.md anti-pattern Before 블록 추가 |

### 수정된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `skills/spring-batch/SKILL.md` | B1 grep: `\.chunk(` → `chunk( + 금지어 filter`; B3 grep: `EnableJdbcJobRepository` 추가, false-PASS 경고 주석 추가 |
| `skills/spring-batch/references/job-design.md` | §5 DataSource 분리에 Before (단일 DataSource 금지) / After 패턴 추가 |
