---
name: spring-init
description: Use whenever the user wants to create, scaffold, bootstrap,
  or initialize a new Spring Boot project in Java with Gradle. Triggers on
  phrases like "새 Spring 프로젝트", "Spring Boot scaffold", "REST API 시작",
  "Spring 프로젝트 만들어줘". Handles project generation via start.spring.io,
  package structure, Gradle setup, and initial application.yml. Always use
  this skill for new Spring projects even if the user doesn't explicitly
  say "initialize" or "scaffold".
---

# Spring Init

Greenfield Spring Boot 프로젝트를 생성한다. 버전은 항상 start.spring.io에서
동적으로 가져오고, 아키텍처 스타일은 사용자에게 확인한다.

## 절대 원칙

- **Spring Boot 버전을 기억해서 쓰지 않는다.** 반드시
  `scripts/fetch-latest-versions.sh` 로 조회한 값을 사용한다.
- **아키텍처 스타일을 가정하지 않는다.** 결정 트리로 추천 + 사용자 확인.
- **`spring-principles` 체크리스트로 생성 결과를 자가 검증한다.**

## 워크플로우

### 1. 요구사항 인터뷰

#### 1-a. 기본 정보

사용자에게 확인 (대화 맥락에 이미 있으면 건너뜀):

- [ ] 도메인/서비스 이름 (artifactId, 예: `order-api`)
- [ ] 영속성 필요 여부 (있으면 `spring-persistence` 스킬로 분기)
- [ ] 인증 필요 여부 (있으면 `spring-security` 스킬로 분기)
- [ ] Java 버전 (기본 21)

#### 1-b. 아키텍처 결정 트리

`references/decision-tree.md` 를 읽고 다음 절차를 따른다.

**먼저 프롬프트 추론**: 사용자 프롬프트에서 각 질문(Q1~Q5)의 답을
추론할 수 있는지 먼저 검토한다. 예시:

- "Hello World REST API" → Q1:a (CRUD), Q2:a (0 통합), Q3:a (단기),
  Q4:a (소규모), Q5:a (해피패스)로 추론 가능 → 모든 질문 스킵
- "결제 시스템 백오피스" → Q1:c (복잡), Q5:c (고커버리지)로 추론 가능,
  나머지는 물어야 함

**추론 충분 시**: 5개 답을 추론한 결과 + 점수 + 추천 아키텍처를
한 번에 제시하고 전체 확인 요청. 사용자가 수정하면 반영.

**추론 부족 시**: Q1부터 순서대로 하나씩 묻는다. 이미 추론한 답이
있는 질문은 스킵하고 추론 결과를 사용자에게 알려 검증받는다.

**점수 계산 & 추천**:
- (a)=Layered +2 / (b)=Hexagonal +2, Layered +1, Clean +1 /
  (c)=Clean +2, Hexagonal +1
- 최고점 스타일 추천
- **동점 시 더 단순한 쪽 우선**: Layered > Hexagonal > Clean

**제시 형식**:
```
프로젝트 성격 분석:
- 도메인: 간단한 CRUD (Q1:a)
- 외부 통합: 없음 (Q2:a)
- 수명: 단기 (Q3:a)
- 팀: 1~2인 (Q4:a)
- 테스트: 해피패스 (Q5:a)

점수: Layered 10 / Hexagonal 0 / Clean 0
추천: **Layered** (근거: 단순한 요구, 오버엔지니어링 방지)

이 분석이 맞나요? 다른 스타일을 선호하시면 지정해주세요.
```

사용자 승인/수정 후 다음 단계로.

### 2. 최신 버전 조회

```bash
./scripts/fetch-latest-versions.sh
```

반환되는 JSON의 `bootVersion`, `javaDefault`를 이후 단계에서 사용.

**절대 규칙 재진술**: 학습 데이터에서 기억한 버전(`3.5.x`, `4.0.x` 등)을
`build.gradle.kts` 어디에도 기입하지 않는다. 스크립트 반환값만 사용한다.

#### 2-a. 실패 분기 — 엔드포인트 구분

`start.spring.io` 는 두 개의 독립 엔드포인트를 사용한다. 실패 유형에 따라 대응이 다르다.

| 엔드포인트 | 사용처 | 실패 시 대응 |
|---|---|---|
| `GET /metadata/client` | `fetch-latest-versions.sh` (버전 조회) | **중단 프로토콜** |
| `POST /starter.zip` | `generate-project.sh` (zip 생성) | **fallback 허용** (아래 2-c) |

#### 2-b. 재시도 정책

어느 쪽이든 1차 실패 시 **2초 → 5초 간격으로 3회 재시도**한다. 재시도 도중
성공하면 정상 흐름을 계속한다. 3회 모두 실패 시 2-c 또는 중단으로 분기.

#### 2-c. zip 생성만 실패한 경우 — 허용 fallback

metadata API 는 성공했는데 `/starter.zip` 만 장애일 때 한해 다음 경로가 허용된다.

1. `fetch-latest-versions.sh` 로 `bootVersion` 을 확보 (반드시 이 값만 사용)
2. Gradle 래퍼·`settings.gradle.kts`·`build.gradle.kts` 를 수동 작성
3. `bootVersion` 은 **`plugins {}` 블록에만** 기입:
   ```kotlin
   id("org.springframework.boot") version "<fetch-latest-versions.sh 반환값>"
   ```
4. `implementation(...)` 등 의존성 좌표에는 절대 버전을 쓰지 않는다 (BOM 관리)
5. 사용자에게 "zip API 장애로 수동 scaffold 적용, Boot 버전은 metadata 조회값 사용" 을 명시 보고

#### 2-d. 중단 프로토콜

metadata API 가 3회 재시도 모두 실패하거나, 네트워크 자체 차단이 확인된 경우:

- 사용자에게 "start.spring.io metadata 접근 실패, 임의 버전 추정 금지 원칙에 따라 중단" 을 보고
- **금지**: 학습 데이터에 있는 버전 숫자를 임시로라도 기입해 진행하는 것
- **금지**: 테스트 통과를 이유로 하드코딩 결과물을 묵인하는 것
- 대안: 네트워크 복구 후 재실행, 또는 오프라인 캐시(있을 경우)로 전환 후 사용자 승인 받기

### 3. 프로젝트 생성

```bash
./scripts/generate-project.sh <artifactId> <dependencies-csv> <outputDir> <javaVersion>
```

기본 의존성 세트:
- 항상 포함: `web,actuator,validation`
- 영속성 선택 시 추가: `data-jpa,mysql` 또는 `mybatis,mysql`
- PostgreSQL 선택 시: `data-jpa,postgresql` 또는 `mybatis,postgresql`
- 보안 선택 시 추가: `security`

> `bootVersion` 앞자리가 **4 이상**이면 `references/gradle-conventions.md` §3 표의 **4.x 열** 아티팩트명을 사용한다. (`spring-boot-starter-web` → `spring-boot-starter-webmvc` 등)

### 4. 패키지 구조 적용

```bash
./scripts/apply-package-structure.sh <projectDir> <style> <basePackagePath>
```

### 5. application.yml 초기화

`references/application-yml.md`의 환경별(local/dev/prod) 템플릿 적용.

### 6. 원칙 체크리스트

`spring-principles` 스킬의 SKILL.md를 읽고 체크리스트로 자가 검증.

## 작성 후 체크리스트

- [ ] `build.gradle.kts`에 bootVersion이 하드코딩되지 않고 플러그인 선언만 있음
- [ ] 패키지 구조가 선택된 아키텍처 스타일과 일치
- [ ] `.gitignore`, `README.md` 포함
- [ ] `application-local.yml` / `application-prod.yml` 분리
- [ ] 최소 1개의 smoke test 포함 (ApplicationContext 로딩 검증)
- [ ] `build.gradle.kts` 아티팩트명이 Boot major 버전과 일치 (3.x: `spring-boot-starter-web`, 4.x: `spring-boot-starter-webmvc`)
- [ ] Java 21 toolchain이 `build.gradle.kts`에 명시됨
