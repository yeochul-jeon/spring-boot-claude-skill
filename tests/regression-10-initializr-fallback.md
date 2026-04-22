# 회고 #10 재검증 가이드 — start.spring.io 장애 fallback

`skills/spring-init/SKILL.md` §2-a ~ §2-d 에 추가된 실패 분기 · 재시도 ·
허용 fallback · 중단 프로토콜이 스킬 문서만으로 자동 작동하는지 확인한다.

> 선행 조건: `tests/manual-test-setup.md` 의 "스킬 인식 경로" 섹션을 먼저 숙지.

---

## 1. 테스트 디렉터리 준비

```bash
mkdir ../test-initializr-fallback && cd ../test-initializr-fallback
mkdir -p .claude
ln -s ../../spring-boot-claude-skill/skills .claude/skills
claude
```

---

## 2. 테스트 A — zip 생성만 실패 (fallback 허용 경로)

### 시뮬레이션

별도 터미널에서 `/etc/hosts` 또는 로컬 프록시로 `start.spring.io/starter.zip`
만 차단하거나, `generate-project.sh` 의 curl 을 임시로 실패시킨다.
(metadata API 는 정상 유지)

### 프롬프트

```
상품 주문 도메인 REST API 프로젝트 시작해줘
```

### 체크리스트

**재시도**
- [ ] zip 호출 1차 실패 후 2초 · 5초 재시도 흔적 (로그 또는 설명) 존재
- [ ] 3회 실패 확정 후에만 fallback 경로 진입

**fallback 경로 준수**
- [ ] `fetch-latest-versions.sh` 가 먼저 성공적으로 실행됨
- [ ] 반환된 `bootVersion` 값을 그대로 `build.gradle.kts` `plugins {}` 블록에 기입
- [ ] 학습 데이터 기반 추정 버전(`3.5.x` / `4.0.x` 등) 기입 0건
- [ ] `implementation(...)` 의존성에 버전 숫자 0건 (BOM 에 위임)
- [ ] 사용자에게 "zip API 장애로 수동 scaffold, Boot 버전은 metadata 값 사용" 명시 보고

**결과물**
- [ ] Gradle 래퍼 · `settings.gradle.kts` · `build.gradle.kts` 수동 생성
- [ ] Boot major 에 맞는 아티팩트명 사용 (3.x vs 4.x)
- [ ] Java 21 toolchain 명시

---

## 3. 테스트 B — metadata 도 실패 (중단 프로토콜)

### 시뮬레이션

`start.spring.io` 호스트 전체를 차단하거나 네트워크를 끊는다.

### 프롬프트

```
상품 주문 도메인 REST API 프로젝트 시작해줘
```

### 체크리스트

**재시도**
- [ ] metadata 호출 1차 실패 후 2초 · 5초 재시도 흔적 존재

**중단 준수**
- [ ] 3회 실패 확정 후 사용자에게 "metadata 접근 실패, 중단" 명시 보고
- [ ] `build.gradle.kts` 등 산출물이 생성되지 않음
- [ ] 학습 데이터 기반 추정 버전을 "임시로라도" 기입한 파일 0건
- [ ] 네트워크 복구 유도 또는 오프라인 캐시 전환을 사용자에게 제안

**금지 패턴 (실패 사유)**
- [ ] `build.gradle.kts` 에 `id("org.springframework.boot") version "3.x.x"` 같은
      추정 버전이 있다면 **즉시 실패**
- [ ] "일단 스캐폴딩 진행하고 나중에 수정" 같은 우회 서술이 있다면 **실패**

---

## 4. 실패 시 매핑표

| 누락 항목 | 확인할 위치 |
|---|---|
| 엔드포인트 구분 누락 | `skills/spring-init/SKILL.md` §2-a 표 |
| 재시도 미수행 | `skills/spring-init/SKILL.md` §2-b |
| fallback 경로 오용(의존성 버전 기입) | `skills/spring-init/SKILL.md` §2-c 4번 |
| 중단 대신 하드코딩 진행 | `skills/spring-init/SKILL.md` §2-d "금지" 블록 |
| 절대 규칙 재진술 누락 회상 실패 | `skills/spring-init/SKILL.md` §2 "절대 규칙 재진술" |

---

## 5. 결과 보고 템플릿

```
## 테스트 A (zip 실패)
- 재시도 로그: [...]
- fallback 경로 진입 여부: [...]
- build.gradle.kts plugins 블록:
  [...]
- 의존성 섹션 (버전 유무):
  [...]

## 테스트 B (metadata 실패)
- 재시도 로그: [...]
- 중단 메시지:
  [...]
- 산출물 존재 여부: [...]

## 체크리스트 결과
- 통과: [...]
- 실패: [...] — 원인 추정
```

---

## 6. 정리

```bash
cd ..
rm -rf test-initializr-fallback
```
