# spring-boot-claude-skill

Claude Code 에서 Spring Boot 프로젝트를 생성·확장할 때 **버전 하드코딩 없이**,
토비의 스프링 설계 원칙을 따르도록 유도하는 Claude Skill 세트.

`Java 21` · `Gradle Kotlin DSL` · `Spring Boot (start.spring.io 동적 조회)`

---

## Why

본 스킬 세트를 연결한 Claude Code 세션에서는 자연어 프롬프트 한 줄로
Spring Boot 프로젝트를 자동 구성할 수 있다 — 최신 버전 조회, 아키텍처 선택,
원칙 기반 코드 생성까지.

다만 LLM 기본 동작에는 반복되는 3가지 문제가 있다:

- 구식 Boot 버전을 학습 데이터에서 그대로 하드코딩
- 아키텍처 스타일(Layered / Hexagonal / Clean)을 묻지 않고 임의 적용
- 필드 주입·Entity 직접 반환 등 안티패턴 무의식적 사용

본 저장소는 이 세 문제를 **스킬 문서(자연어 규칙) + 스크립트** 조합으로 해결한다.
Claude Code 의 Skill 메커니즘을 활용해 프로젝트마다 동적으로 버전을 조회하고,
아키텍처를 인터뷰하며, 원칙 체크리스트로 자가 검증한다.

---

## 아키텍처 개요

### 스킬 참조 관계

```
spring-init ──▶ spring-principles ◀── spring-web
     │                ▲                    │
     ▼                │                    ▼
spring-persistence ───┴──── spring-security
                                spring-testing
```

### 스킬 목록

| 스킬 | 역할 |
|---|---|
| `spring-init` | entry point. 프로젝트 초기화·Gradle 설정·패키지 구조·아키텍처 인터뷰 |
| `spring-principles` | 공용 설계 원칙 — 다른 모든 스킬이 참조 |
| `spring-web` | REST 컨트롤러·DTO·예외 처리 |
| `spring-persistence` | JPA / MyBatis 선택 가능한 영속성 계층 |
| `spring-security` | 세션 / JWT 인증·인가 |
| `spring-testing` | slice test · TestContainers 컨벤션 |

### 핵심 설계 결정

- **버전 동적 조회**: `skills/spring-init/scripts/fetch-latest-versions.sh` 가 start.spring.io 메타데이터 API 를 호출해 최신 `bootVersion` 을 반환. 학습 데이터 버전 사용 금지.
- **아키텍처 결정 트리**: Q1~Q5 점수제로 Layered / Hexagonal / Clean 중 추천. 동점 시 Layered 우선 (오버엔지니어링 방지).
- **`spring-principles` 공통 참조**: 필드 주입 금지·생성자 주입·DTO 분리·Rich domain 등의 원칙을 각 스킬이 동일 소스에서 참조.

---

## 디렉터리 구조

```
skills/
  spring-init/        프로젝트 scaffold + 아키텍처 인터뷰 + 스크립트
    SKILL.md
    references/       decision-tree, gradle-conventions, application-yml 등
    scripts/          fetch-latest-versions.sh, generate-project.sh, apply-package-structure.sh
  spring-principles/  공용 설계 원칙
    SKILL.md
    references/       anti-patterns.md 등
    templates/        공통 코드 템플릿
  spring-web/         REST 컨트롤러·DTO·예외 처리
    SKILL.md
    references/       rest-conventions, dto-patterns, exception-handling, validation
  spring-persistence/ JPA / MyBatis
    SKILL.md
    references/       selection-guide, jpa, mybatis, transaction
  spring-security/    세션 / JWT
    SKILL.md
    references/       selection-guide, session-auth, jwt-auth, cors, password-encoding
  spring-testing/     slice test · TestContainers
    SKILL.md
    references/       slice-tests, testcontainers, fixtures
tests/                케이스 · 회귀 검증 가이드
docs/                 ADR, 회고 로그
```

각 스킬은 `SKILL.md` frontmatter 의 `description` 필드로 트리거된다.
Claude Code 가 사용자 프롬프트와 description 을 매칭해 자동으로 스킬을 invoke 한다.

---

## 빠른 시작

### 1단계. 스킬 연결

```bash
git clone https://github.com/<repo>/spring-boot-claude-skill.git ../spring-boot-claude-skill
mkdir -p .claude
ln -s ../../spring-boot-claude-skill/skills .claude/skills
claude
```

`.claude/skills/` 심볼릭 링크가 Claude Code 의 스킬 인식 경로다.

### 2단계. 새 프로젝트 생성

Claude 에게 입력:

```
상품 주문 도메인 REST API 프로젝트 시작해줘
```

→ `spring-init` 자동 발동 → `fetch-latest-versions.sh` 실행 → 아키텍처 인터뷰 (Q1~Q5) → scaffold 생성.

### 3단계. 기능 추가

```
회원 가입 Controller, Service, Repository 만들어줘
```

→ `spring-web` + `spring-persistence` + `spring-principles` 자동 결합.
필드 주입 없이 생성자 주입, DTO 분리, `@Transactional` 위치까지 원칙 적용.

---

## 검증

| 항목 | 위치 |
|---|---|
| 7개 시나리오 케이스 체크리스트 | `tests/cases.md` |
| 회고 #8 보안 회귀 가이드 | `tests/regression-8-security-rest-api.md` |
| 회고 #9 아키텍처 인터뷰 회귀 가이드 | `tests/regression-9-architecture-interview.md` |
| 회고 #10 Initializr fallback 회귀 가이드 | `tests/regression-10-initializr-fallback.md` |
| 수동 테스트 환경 설정 | `tests/manual-test-setup.md` |

---

## 프로젝트 문서

| 파일 | 내용 |
|---|---|
| `CLAUDE.md` | Claude Code 전용 작업 규칙 (절대 원칙 포함) |
| `PLAN.md` | 설계 플랜 (A~E 섹션) |
| `PLAN-implementation.md` | 구현 플랜 (F~J 섹션) |
| `docs/ADR.md` | 아키텍처 결정 기록 |
| `docs/logs/` | 회고 로그 |

---

## License

MIT — `LICENSE` 참조.
