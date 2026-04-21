# Spring Boot Claude Skill 세트 — 구현 플랜 (F–J)

> `PLAN.md`의 설계 결정을 바탕으로, Claude Code에서 실제로 파일을 만들 때
> 참조할 실행 가능한 내용을 담는다.

## F. SKILL.md 본문 설계

각 스킬은 YAML 프론트매터 + 본문으로 구성. 본문은 500줄 이하 유지,
상세는 references/로 분리 (점진적 공개).

### F-1. `spring-init/SKILL.md` (전문)

```markdown
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

\`\`\`bash
./scripts/fetch-latest-versions.sh
\`\`\`

반환되는 JSON의 `bootVersion`, `javaDefault`를 이후 단계에서 사용.
실패하면 사용자에게 "start.spring.io 접근 실패"를 알리고 중단.
임의로 버전을 추정해서 진행하지 않는다.

### 3. 프로젝트 생성

\`\`\`bash
./scripts/generate-project.sh <artifactId> <dependencies-csv> <outputDir> <javaVersion>
\`\`\`

기본 의존성 세트:
- 항상 포함: `web,actuator,validation`
- 영속성 선택 시 추가: `data-jpa,postgresql` 또는 `mybatis,postgresql`
- 보안 선택 시 추가: `security`

### 4. 패키지 구조 적용

\`\`\`bash
./scripts/apply-package-structure.sh <projectDir> <style> <basePackagePath>
\`\`\`

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
- [ ] Java 21 toolchain이 `build.gradle.kts`에 명시됨
```

### F-2. 나머지 스킬의 프론트매터 (description)

```yaml
# spring-web
name: spring-web
description: Use when building REST APIs with Spring Boot, including
  @RestController design, request/response DTOs, @RestControllerAdvice
  for exception handling, and Bean Validation. Trigger on "REST API",
  "controller 추가", "예외 처리", "DTO 설계". Always separates DTOs
  from entities and uses ProblemDetail (RFC 7807) for errors.
```

```yaml
# spring-persistence
name: spring-persistence
description: Use when implementing a persistence layer in Spring Boot
  with either JPA/Hibernate or MyBatis. Trigger on "DB 연결", "엔티티 설계",
  "리포지토리", "Mapper", "트랜잭션 경계". The skill FIRST asks whether to
  use JPA or MyBatis (see references/selection-guide.md), then proceeds
  with the chosen path.
```

```yaml
# spring-security
name: spring-security
description: Use when configuring authentication and authorization in
  Spring Boot. Trigger on "로그인", "인증", "권한", "JWT", "세션". The skill
  asks session-based vs JWT first, then configures SecurityFilterChain,
  password encoding, and CORS appropriately.
```

```yaml
# spring-testing
name: spring-testing
description: Use when writing tests for Spring Boot code. Trigger on
  "테스트 작성", "@WebMvcTest", "@DataJpaTest", "통합 테스트",
  "TestContainers". Enforces slice tests, TestContainers for integration,
  and builder-based fixtures over random data.
```

```yaml
# spring-principles
name: spring-principles
description: Use whenever writing, reviewing, or refactoring Java/Spring
  code. This skill encodes design principles from 토비의 스프링 - constructor
  injection, DTO-entity separation, testability, rich domain, and anti-pattern
  avoidance. All other spring-* skills reference this for their
  self-verification checklist. Always consult this before declaring Spring
  code "done".
```

## G. references/ 내용 개요

각 파일이 다룰 범위만 정의. 실제 내용은 Claude Code에서 스킬 구현 시 작성.

### spring-init/references/
- **`decision-tree.md`**: 아키텍처 선택 결정 트리 (Q1~Q5 질문 전문,
  선택지별 점수 매핑, 동점 규칙, 추론 예시, 제시 템플릿). **spring-init
  진입 시 가장 먼저 참조하는 파일.** (상세 전문은 G-1 참조)
- **`starter-api.md`**: start.spring.io API 명세 (GET /metadata/client,
  POST /starter.zip 파라미터표, dependency id 매핑)
- **`architecture-styles.md`**: Layered / Hexagonal / Clean 각각의
  언제 쓰는지, 구조 특징, 장단점. decision-tree.md 가 추천한 스타일의
  구현 세부를 설명.
- **`package-structure.md`**: 스타일별 디렉터리 트리 예시 3종
- **`gradle-conventions.md`**: Kotlin DSL 권장 패턴, `versions.toml`
  중앙화, 플러그인 선언 순서
- **`application-yml.md`**: `application.yml` + 프로파일별 오버라이드
  구조, 민감정보 처리 (환경변수 참조)

### G-1. `decision-tree.md` 전문

```markdown
# Architecture Decision Tree

`spring-init` 진입 시 **첫 번째로 참조하는 문서**. 아키텍처 스타일은
가정하지 않는다. 이 트리로 추천하고 사용자 최종 승인.

## 5개 질문 (Q1 → Q5 순차)

### Q1. 도메인 복잡도

- (a) 거의 CRUD. 비즈니스 규칙이 단순한 validation 수준
- (b) 일부 비즈니스 규칙 존재. 상태 전이나 권한 정책 등
- (c) 복잡한 도메인 규칙. 다수의 invariant, 정책, 전략

### Q2. 외부 시스템 통합 개수

- (a) 0~1개 (DB만, 또는 DB + 단일 외부 API)
- (b) 2~3개
- (c) 4개+ (메시징, 외부 API, 캐시, 검색 등)

### Q3. 예상 수명

- (a) 프로토타입 또는 1년 미만 단기 프로젝트
- (b) 1~3년
- (c) 5년+, 장기 유지보수

### Q4. 팀 규모

- (a) 1~2인
- (b) 3~5인
- (c) 6인+

### Q5. 테스트 요구

- (a) 해피패스 위주. 핵심 시나리오만
- (b) 단위 테스트 + 통합 테스트 체계적
- (c) 규제·장애 대응으로 고커버리지(80%+) 필수

## 점수 매핑

| 답변 | Layered | Hexagonal | Clean |
|---|---|---|---|
| (a) | +2 | 0 | 0 |
| (b) | +1 | +2 | +1 |
| (c) | 0 | +1 | +2 |

최고점 스타일이 추천.

## 동점 처리

**더 단순한 쪽 우선**: Layered > Hexagonal > Clean

근거: YAGNI. 단순한 구조에서 시작해 필요할 때 진화하는 편이,
처음부터 과도한 추상화를 얹는 것보다 실패 확률이 낮다.

## 프롬프트 추론 우선

사용자 프롬프트에 이미 각 질문의 답을 알 수 있는 힌트가 있으면
질문을 **생략**한다. 예시:

- "Hello World REST API" → 모두 (a) → Layered
- "간단한 회원 CRUD" → Q1:a, Q5:a 추론. 나머지는 더 필요 시 질문
- "결제·정산 백오피스, 5년 운영" → Q1:c, Q3:c 추론
- "팀 10명이 쓰는 MSA 한 조각" → Q4:c 추론

추론한 답 + 추천 결과를 한 번에 제시하고 사용자 확인. 추론이 애매한
차원만 Q 순서대로 추가 질문.

## 제시 템플릿

\`\`\`
프로젝트 성격 분석:
- 도메인 복잡도: {답변} (Q1:{a/b/c})
- 외부 통합: {답변} (Q2:{a/b/c})
- 예상 수명: {답변} (Q3:{a/b/c})
- 팀 규모: {답변} (Q4:{a/b/c})
- 테스트 요구: {답변} (Q5:{a/b/c})

점수: Layered {L} / Hexagonal {H} / Clean {C}
추천: **{Style}** (근거: {한 줄 이유})

이 분석이 맞나요? 다른 스타일을 선호하시면 지정해주세요.
\`\`\`

## 원칙

- 점수는 **추천 근거**이지 강제가 아니다
- 사용자가 점수 무시하고 다른 스타일 선택해도 존중
- 단, 사용자 선택이 점수와 크게 다르면 "~한 이유로 Layered가
  추천인데 Clean을 선택하신 이유가 있나요?"라고 한 번 확인
- 대답 들으면 그대로 진행 (잔소리 금지)
```

### spring-web/references/
- **`rest-conventions.md`**: URL 네이밍 (명사 복수, kebab-case),
  HTTP 메서드 사용 기준, 상태 코드 매핑표
- **`dto-patterns.md`**: Request/Response DTO 분리, record 활용,
  Entity ↔ DTO 매핑 (MapStruct vs 수동)
- **`exception-handling.md`**: `@RestControllerAdvice` 구조, ProblemDetail,
  도메인 예외 → HTTP 상태 매핑
- **`validation.md`**: Bean Validation 어노테이션, 커스텀 validator,
  validation group

### spring-persistence/references/
- **`selection-guide.md`**: JPA vs MyBatis 의사결정 체크리스트
  (복잡한 조회, 쿼리 튜닝 필요성, 팀 숙련도)
- **`jpa.md`**: Entity 설계 (연관관계, 지연로딩), Repository 패턴,
  N+1 회피, Auditing
- **`mybatis.md`**: Mapper 인터페이스, XML vs 어노테이션, Dynamic SQL,
  ResultMap 설계
- **`transaction.md`**: `@Transactional` 경계 (Service 계층), readOnly
  최적화, 전파 속성

### spring-security/references/
- **`session-auth.md`**: Spring Session, 세션 고정 공격 대응
- **`jwt-auth.md`**: JWT 발급/검증 필터, Refresh Token, 키 관리
- **`password-encoding.md`**: BCrypt/Argon2 선택, DelegatingPasswordEncoder
- **`cors.md`**: CorsConfigurationSource, 프런트 도메인 허용 정책

### spring-testing/references/
- **`slice-tests.md`**: `@WebMvcTest`, `@DataJpaTest`, `@JsonTest`의
  언제 쓰는지와 범위
- **`testcontainers.md`**: PostgreSQL/Redis 컨테이너 설정, 재사용
  (reuse), 테스트 컨텍스트 캐싱
- **`fixtures.md`**: 테스트 데이터 빌더 패턴, ObjectMother,
  Faker 사용 기준

### spring-principles/references/
- **`di.md`**: 생성자 주입 원칙, 순환 참조 탐지
- **`separation-of-concerns.md`**: Controller/Service/Repository 각 책임
- **`testability.md`**: 테스트하기 쉬운 설계의 특징
- **`rich-domain.md`**: Entity에 행위 부여, VO 도입
- **`anti-patterns.md`**: 필드 주입, Service가 Entity 아는 척,
  Controller에서 Repository 직접 호출, Anemic domain 등

### spring-principles/templates/
각 파일은 동일 구조:
- `## Before` (안티패턴 코드)
- `## After` (권장 코드)
- `## 왜` (2~3문장)
- `## 관련 원칙` (references/의 관련 md 링크)

템플릿 목록:
- `constructor-injection.md` (필드 주입 → 생성자 주입)
- `dto-entity-separation.md` (Entity 직접 반환 → DTO 매핑)
- `rich-domain.md` (Anemic Entity + Service 로직 → Entity 메서드)
- `template-method-pattern.md` (반복 try-catch → 템플릿)
- `value-object.md` (Money를 long으로 → Money VO)

---

## H. scripts/ 전문

**반드시 `chmod +x`를 실행할 것.**

### H-1. `fetch-latest-versions.sh`

```bash
#!/bin/bash
# 최신 Spring Boot/Java 버전을 start.spring.io에서 조회해 JSON으로 반환.
# 절대 버전을 하드코딩하지 말 것. 이 스크립트를 사용.
set -euo pipefail

METADATA=$(curl -sfL https://start.spring.io/metadata/client) || {
  echo "ERROR: start.spring.io 접근 실패. 네트워크 확인 필요." >&2
  exit 1
}

BOOT_VERSION=$(echo "$METADATA" | jq -r '.bootVersion.default')
JAVA_DEFAULT=$(echo "$METADATA" | jq -r '.javaVersion.default')
JAVA_VALUES=$(echo "$METADATA" | jq -c '.javaVersion.values | map(.id)')

cat <<EOF
{
  "bootVersion": "$BOOT_VERSION",
  "javaDefault": "$JAVA_DEFAULT",
  "javaAvailable": $JAVA_VALUES
}
EOF
```

### H-2. `generate-project.sh`

```bash
#!/bin/bash
# Usage: ./generate-project.sh <artifactId> <dependencies-csv> [outputDir] [javaVersion]
# 예: ./generate-project.sh order-api web,actuator,validation,data-jpa,postgresql ./out 21
set -euo pipefail

ARTIFACT="${1:?artifactId가 필요합니다}"
DEPS="${2:?의존성 CSV가 필요합니다 (예: web,actuator)}"
OUT="${3:-./$ARTIFACT}"
JAVA_VER="${4:-21}"

VERSIONS=$("$(dirname "$0")/fetch-latest-versions.sh")
BOOT_VERSION=$(echo "$VERSIONS" | jq -r .bootVersion)

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PKG_NAME="com.example.$(echo "$ARTIFACT" | tr -d '-_')"

curl -sfL "https://start.spring.io/starter.zip" \
  -d "type=gradle-project-kotlin" \
  -d "language=java" \
  -d "bootVersion=$BOOT_VERSION" \
  -d "groupId=com.example" \
  -d "artifactId=$ARTIFACT" \
  -d "name=$ARTIFACT" \
  -d "packageName=$PKG_NAME" \
  -d "packaging=jar" \
  -d "javaVersion=$JAVA_VER" \
  -d "dependencies=$DEPS" \
  -o "$TMP/project.zip"

mkdir -p "$OUT"
unzip -q "$TMP/project.zip" -d "$OUT"

echo "생성 완료: $OUT (Spring Boot $BOOT_VERSION, Java $JAVA_VER)"
echo "base package: $PKG_NAME"
```

### H-3. `apply-package-structure.sh`

```bash
#!/bin/bash
# Usage: ./apply-package-structure.sh <projectDir> <style> <basePackagePath>
# style: layered | hexagonal | clean
# 예: ./apply-package-structure.sh ./order-api hexagonal com/example/orderapi
set -euo pipefail

PROJECT="${1:?projectDir 필요}"
STYLE="${2:?style 필요 (layered|hexagonal|clean)}"
PKG="${3:?basePackagePath 필요 (예: com/example/orderapi)}"

SRC="$PROJECT/src/main/java/$PKG"
TEST="$PROJECT/src/test/java/$PKG"
mkdir -p "$SRC" "$TEST"

case "$STYLE" in
  layered)
    mkdir -p "$SRC"/{controller,service,repository,domain,dto,config}
    ;;
  hexagonal)
    mkdir -p "$SRC"/{application/{port/{in,out},service},domain,adapter/{in/web,out/persistence},config}
    ;;
  clean)
    mkdir -p "$SRC"/{domain,application/{usecase,port},infrastructure/{persistence,config},presentation/web}
    ;;
  *)
    echo "ERROR: 알 수 없는 스타일: $STYLE (layered|hexagonal|clean 중 선택)" >&2
    exit 1
    ;;
esac

echo "패키지 구조 적용 완료: $STYLE"
```

---

## I. 테스트 케이스 & 평가

`tests/cases.md`에 수동 실행할 테스트 시나리오를 둔다.
각 케이스는 프롬프트 + 검증 체크리스트 쌍으로 구성.

### 케이스 1: 버전 하드코딩 방지
- **프롬프트**: "Spring Boot 최신 버전으로 간단한 Hello World REST API 프로젝트 만들어줘"
- **검증**:
  - [ ] `fetch-latest-versions.sh`를 실행했는가
  - [ ] 생성된 `build.gradle.kts`의 `org.springframework.boot` 플러그인
        버전이 스크립트 반환값과 일치
  - [ ] 3.5.3, 3.4.x 같은 구식 버전이 등장하지 않음
  - [ ] 대화 중 스크립트 실행 없이 버전을 말하지 않음

### 케이스 2: 아키텍처 인터뷰
- **프롬프트**: "상품 주문 도메인 REST API 프로젝트 시작해줘"
- **검증**:
  - [ ] 아키텍처 스타일을 물었는가
  - [ ] 묻지 않고 layered를 기본 적용했다면 실패
  - [ ] 선택에 따라 `apply-package-structure.sh`가 올바른 인자로 실행됨

### 케이스 3: 영속성 분기
- **프롬프트**: "PostgreSQL 연동하는 회원 CRUD 프로젝트 만들어"
- **검증**:
  - [ ] `spring-persistence` 스킬이 추가 invoke 되었는가
  - [ ] JPA vs MyBatis 선택 질문이 나왔는가
  - [ ] TestContainers 의존성이 포함됐는가
  - [ ] `@Transactional`이 Service 계층에 위치

### 케이스 4: 원칙 준수
- **프롬프트**: "간단한 회원 가입 Controller, Service, Repository 만들어줘"
- **검증**:
  - [ ] 필드 주입(`@Autowired` private field)이 없음
  - [ ] 생성자 주입 + `final` 필드
  - [ ] Controller가 Entity를 직접 반환하지 않음 (DTO 매핑)
  - [ ] Service에 `@Transactional` 적절히 배치
  - [ ] `spring-principles` 스킬이 대화 중 참조됨

### 케이스 5: 보안 + 세션/JWT 선택
- **프롬프트**: "로그인 있는 REST API 프로젝트 만들어"
- **검증**:
  - [ ] 세션 vs JWT 선택 질문이 나왔는가
  - [ ] BCrypt 기본, DelegatingPasswordEncoder 사용
  - [ ] CORS 설정 포함

### 평가 방법
Claude Code에서 각 프롬프트 실행 → 결과 코드 수동 리뷰 → 실패 항목을
스킬 본문·references에 반영하고 재실행. 케이스 1은 가장 자주 돌려서
버전 하드코딩 리그레션을 계속 감시.

---

## J. Claude Code 배포

### 디렉터리 배치

**글로벌 (모든 프로젝트에서 사용)**:
```
~/.claude/skills/
├── spring-init/
├── spring-web/
├── spring-persistence/
├── spring-security/
├── spring-testing/
└── spring-principles/
```

**프로젝트 로컬**:
```
<project-root>/.claude/skills/
```

### 레포 구성 (공유용)

```
tobyilee-spring-skills/          # GitHub 공개 레포
├── README.md
├── skills/
│   ├── spring-init/
│   ├── spring-web/
│   ├── spring-persistence/
│   ├── spring-security/
│   ├── spring-testing/
│   └── spring-principles/
├── tests/
│   └── cases.md
├── CHANGELOG.md
└── LICENSE
```

### 설치

```bash
git clone https://github.com/<you>/tobyilee-spring-skills.git ~/tobyilee-spring-skills
mkdir -p ~/.claude/skills
for skill in ~/tobyilee-spring-skills/skills/*/; do
  ln -sf "$skill" ~/.claude/skills/
done
```

스크립트 실행 권한:
```bash
chmod +x ~/tobyilee-spring-skills/skills/spring-init/scripts/*.sh
```

### Claude Code 세션 시작 프롬프트

스킬을 만들기 위한 첫 세션에서 사용할 프롬프트:

```
~/tobyilee-spring-skills 디렉터리에 Spring Boot 스킬 세트를 만들려고 해.
구성은 spring-init, spring-web, spring-persistence, spring-security,
spring-testing, spring-principles 6개. 각 스킬은 SKILL.md + references/
(+ spring-init은 scripts/) 구조. spring-principles는 추가로 templates/ 포함.

첨부한 PLAN.md와 PLAN-implementation.md를 먼저 읽고, skill-creator
스킬을 사용해서 spring-init부터 만들어줘. 다음 순서로:

1. 디렉터리 구조 생성
2. spring-init/scripts/ 3개 스크립트 작성 후 chmod +x
3. 스크립트 동작 확인 (fetch-latest-versions.sh 실제 실행)
4. spring-init/SKILL.md 작성 (PLAN-implementation.md F-1 참조)
5. spring-init/references/ 5개 파일 작성
6. tests/cases.md의 케이스 1, 2를 실행해서 동작 확인

spring-init 완성되면 멈추고 결과를 보여줘. 그 다음 spring-principles,
그 다음 나머지 스킬 순서로 진행할 거야.
```

### 이후 세션

- 스킬 하나 완성 → 테스트 케이스 실행 → 실패 항목 반영 → 다음 스킬
- `spring-principles`는 `spring-init` 다음에 만드는 걸 권장 (다른 스킬들이 참조하므로)
- 순서: `spring-init` → `spring-principles` → `spring-web` → `spring-persistence` → `spring-security` → `spring-testing`

### 유지보수

- 분기마다 `fetch-latest-versions.sh`를 돌려서 기본값이 업데이트되는지 확인
- Spring Boot 메이저 버전 업(예: 5.0) 발표되면 `references/` 내용 검토
- 테스트 케이스 정기 실행 (특히 케이스 1)
