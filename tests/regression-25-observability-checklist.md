# Regression Test #25 — spring-observability 체크리스트 empirical 검증

날짜 초안: 2026-04-23

---

## 목적

`spring-observability` SKILL.md 의 자가 검증 체크리스트가 실제 코드에서
결함을 빠짐없이 탐지하는지 empirical 하게 검증한다.

---

## §1 사전 준비

```bash
SANDBOX=/Users/cjenm/github/test-retro25-observability   # BASELINE
SRC=$SANDBOX/src/main/java
RES=$SANDBOX/src/main/resources

SANDBOX_V2=/Users/cjenm/github/test-retro25-observability-v2  # 2차 회전
SRC_V2=$SANDBOX_V2/src/main/java
RES_V2=$SANDBOX_V2/src/main/resources
```

시나리오: "주문 생성 API (`POST /api/v1/orders`) 에 커스텀 Micrometer 카운터,
OTel tracing sampling, Correlation-ID MDC 필터, Structured JSON logging 적용.
Actuator 는 `health`/`info`/`prometheus` 만 노출."

---

## §2 grep 자동 검증

아래 명령은 BASELINE(`$SRC`, `$RES`)과 2차 회전(`$SRC_V2`, `$RES_V2`) 각각에 대해
`SRC`/`RES` 를 치환해 실행한다.

```bash
# O1: Actuator wildcard 노출 (0건이어야 PASS)
# YAML 큰따옴표("*") · 작은따옴표('*') · properties(include=*) 세 변형 탐지
echo "=== [O1] Actuator wildcard 노출 ==="
grep -rn 'include.*"\*"\|include: "\*"\|include.*'"'"'\*'"'"'\|include=\*' $RES/ || echo "PASS"

# O2: MeterRegistry 사용 (수동)
echo "=== [O2] MeterRegistry 사용 ==="
grep -rn "MeterRegistry" $SRC/ | grep -v "//\|import" | head -5
echo "MANUAL: io.prometheus.client 직접 import 없는지 확인"

# O3: CorrelationId / MDC 전파 필터 존재 (1건 이상이어야 PASS)
echo "=== [O3] Correlation ID 필터 ==="
grep -rn "CorrelationId\|correlationId\|MDC.put" $SRC/ | head -3
echo "MANUAL: Filter/OncePerRequestFilter 구현체 내부 MDC.put 호출인지 확인"

# O4: Structured logging (1건 이상이어야 PASS)
echo "=== [O4] Structured logging ==="
grep -rn "LogstashEncoder\|logstash-logback\|StructuredLogging\|logging\.structured\.format" $SRC/../resources/ 2>/dev/null | head -3
echo "(위 결과 1건 이상 → PASS)"

# O5: tracing sampling (1건 이상이어야 PASS)
# 주의: YAML은 sampling: / probability: 두 줄 분리
echo "=== [O5] Tracing sampling ==="
grep -rn "sampling\.probability\|sampling:" $RES/ | head -5
echo "MANUAL: YAML 사용 시 probability: 값이 명시되어 있는지 수동 확인"
```

---

## §3 수동 체크리스트

```
Actuator / 메트릭
- [ ] Actuator include 목록이 명시적으로 나열됨 ("*" 없음)
- [ ] health show-details: when_authorized 설정됨
- [ ] MeterRegistry를 통해 커스텀 비즈니스 메트릭 등록 (직접 Prometheus API 사용 금지)

Tracing
- [ ] management.tracing.sampling.probability 값이 명시됨
- [ ] OTel/Micrometer Tracing 의존성 존재 (벤더 직접 SDK 없음)

Logging
- [ ] logback-spring.xml 또는 logging.structured.format 으로 JSON 구조화 로그 설정
- [ ] correlationId가 MDC에 포함되어 LogstashEncoder에 전달됨

Filter
- [ ] CorrelationIdFilter 가 @Order(Ordered.HIGHEST_PRECEDENCE) 또는 가장 높은 우선순위로 등록됨
- [ ] MDC.remove() finally 블록에서 정리됨

spring-principles
- [ ] 생성자 주입 100% (@Autowired 필드 없음)
- [ ] 엔티티 직접 노출 없음 (DTO 반환)
- [ ] spring-principles 체크리스트 전 항목 통과
```

---

## §4 실행 결과 기록

| 날짜 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 2026-04-23 | BASELINE (orderApi) | PASS (탐지 공백 3건) | O1~O5 실제 결함 0건; 아래 탐지 공백 수집 |
| 2026-04-23 | 2차 회전 (SKILL.md 로드 후 재생성) | PASS | O1~O5 전부 PASS; @Order(HIGHEST_PRECEDENCE) + probability 명시 |

### 2026-04-23 탐지 공백 목록

| 코드 | 탐지 공백 | 분류 |
|------|-----------|------|
| O5_YAML_SPLIT | v0.1 O5 grep: `sampling.probability\|tracing` — YAML에서 `sampling:` 과 `probability:` 는 두 줄로 분리되므로 `sampling.probability` 단일 문자열 탐지 불가. `tracing:` 만으로 PASS 판정 — sampling 미설정 시 false-PASS | 탐지 공백 (latent) — grep을 `sampling\.probability\|sampling:` 으로 수정, MANUAL 필수 격상 |
| O1_SINGLE_QUOTE | v0.1 O1 grep: 큰따옴표 `"*"` 만 탐지 — `include: '*'` (작은따옴표) 미탐지 | 탐지 공백 (latent) — 단일따옴표 `'\*'` + `include=\*` (properties) 변형 추가 |
| O4_BOOT34 | v0.1 O4 grep: `LogstashEncoder\|logstash-logback\|StructuredLogging` — Boot 3.4+ `logging.structured.format.console=logstash` 신규 설정 미탐지 | 탐지 공백 (latent) — `logging\.structured\.format` 패턴 추가 |

### 수정된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `skills/spring-observability/SKILL.md` | O1 grep: 단일따옴표 `'\*'` + `include=\*` 변형 추가; O4 grep: `logging\.structured\.format` 추가; O5 grep: `sampling:` 으로 확장 + MANUAL 수동 확인 필수 격상; O2/O3 MANUAL 안내 명시 |

### 2차 회전 관찰

SKILL.md 로드 후 생성 코드에서 추가된 사항:
- `@Order(Ordered.HIGHEST_PRECEDENCE)` 명시 (BASELINE은 `@Order(1)` 사용)
- `probability: 1.0` 주석 포함 명시 ("O5: OTel sampling explicitly set")
- OrderService 주석에 "O2: MeterRegistry, not raw Prometheus" 명시

---

## §A 자기참조 검증

```bash
SKILLS=/Users/cjenm/github/spring-boot-claude-skill/skills
# 버전 하드코딩 없음
grep -rEn '[0-9]+\.[0-9]+\.[0-9]+' $SKILLS/spring-observability/ || echo "PASS"

# O1 grep 자체에 wildcard 없음
grep -rn 'include.*"\*"\|include: "\*"' $SKILLS/spring-observability/ \
  | grep -v "grep -rn\|O1.*Actuator\|# O1\|PASS\|금지" || echo "PASS"
```

→ 버전 하드코딩 없음 (PASS) / O1 자기참조 위반 없음 (PASS)
