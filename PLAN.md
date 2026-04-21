# Spring Boot Claude Skill 세트 구축 플랜

> 목적: Claude가 Spring Boot 프로젝트를 생성할 때 **구식 버전을 하드코딩하지 않고**,
> 토비의 스프링 설계 원칙을 따르며, 프로젝트마다 적절한 아키텍처를 선택하도록
> 유도하는 Claude Code Skill 세트를 만든다.
>
> 이 문서는 Claude Code 세션에 첨부해서 스킬 구현을 단계별로 진행하기 위한
> 실행 가능한 플랜이다.

## 핵심 결정 요약

| 항목 | 결정 |
|---|---|
| 스킬 구조 | 주제별 분리 (6개 스킬) |
| 시나리오 가중치 | 신규 프로젝트 생성 (scaffolding) 중심 |
| 언어/빌드 | Java 21 + Gradle (Kotlin DSL) |
| 영속성 | JPA + MyBatis 둘 다 지원 (런타임 선택) |
| 아키텍처 | 프로젝트마다 선택 (스킬이 인터뷰) |
| 원칙 반영 강도 | 원칙 + 템플릿 코드 + 안티패턴 (상세) |
| Boot 버전 처리 | **하드코딩 금지. 항상 start.spring.io 메타데이터 API 호출** |

## 스킬 세트 (6개)

1. **`spring-init`** — entry point. 프로젝트 초기화, Gradle 설정, 패키지 구조, 아키텍처 인터뷰
2. **`spring-web`** — REST 컨트롤러, DTO, 예외 처리
3. **`spring-persistence`** — JPA/MyBatis 선택 가능한 영속성 계층
4. **`spring-security`** — 인증/인가
5. **`spring-testing`** — 테스트 컨벤션 (slice test, TestContainers)
6. **`spring-principles`** — 공용 설계 원칙 문서 (토비 스타일)

---

## A. 스킬 구조

```
.claude/skills/
├── spring-init/
│   ├── SKILL.md
│   ├── references/
│   │   ├── decision-tree.md
│   │   ├── starter-api.md
│   │   ├── architecture-styles.md
│   │   ├── package-structure.md
│   │   ├── gradle-conventions.md
│   │   └── application-yml.md
│   └── scripts/
│       ├── fetch-latest-versions.sh
│       ├── generate-project.sh
│       └── apply-package-structure.sh
├── spring-web/
│   ├── SKILL.md
│   └── references/
│       ├── rest-conventions.md
│       ├── dto-patterns.md
│       ├── exception-handling.md
│       └── validation.md
├── spring-persistence/
│   ├── SKILL.md
│   └── references/
│       ├── selection-guide.md      # JPA vs MyBatis 의사결정
│       ├── jpa.md
│       ├── mybatis.md
│       └── transaction.md
├── spring-security/
│   ├── SKILL.md
│   └── references/
│       ├── session-auth.md
│       ├── jwt-auth.md
│       ├── password-encoding.md
│       └── cors.md
├── spring-testing/
│   ├── SKILL.md
│   └── references/
│       ├── slice-tests.md
│       ├── testcontainers.md
│       └── fixtures.md
└── spring-principles/
    ├── SKILL.md
    ├── references/
    │   ├── di.md
    │   ├── separation-of-concerns.md
    │   ├── testability.md
    │   ├── rich-domain.md
    │   └── anti-patterns.md
    └── templates/
        ├── constructor-injection.md
        ├── dto-entity-separation.md
        ├── rich-domain.md
        ├── template-method-pattern.md
        └── value-object.md
```

## A-1. 아키텍처 선택 (결정 트리)

`spring-init`은 아키텍처 스타일을 **가정하지 않는다**. 대신 결정 트리로
추천하고 사용자 최종 승인을 받는다.

### 5개 질문 (Q1 → Q5 순차)

| # | 질문 | 선택지 (a/b/c) |
|---|---|---|
| Q1 | 도메인 복잡도 | 거의 CRUD / 일부 비즈니스 규칙 / 복잡한 도메인 규칙 |
| Q2 | 외부 통합 개수 | 0~1 / 2~3 / 4+ |
| Q3 | 예상 수명 | 프로토타입·단기 / 1~3년 / 5년+ |
| Q4 | 팀 규모 | 1~2인 / 3~5인 / 6인+ |
| Q5 | 테스트 요구 | 해피패스 / 단위+통합 / 고커버리지 필수 |

### 점수 매핑

| 답변 | Layered | Hexagonal | Clean |
|---|---|---|---|
| (a) | +2 | 0 | 0 |
| (b) | +1 | +2 | +1 |
| (c) | 0 | +1 | +2 |

최고점 스타일 추천. **동점 시 더 단순한 쪽 우선**: Layered > Hexagonal > Clean.
근거는 YAGNI — 단순하게 시작하고 필요할 때 진화.

### 질문 생략 규칙

프롬프트에 이미 충분한 힌트가 있으면(예: "Hello World REST API", "간단한
CRUD") 스킬이 각 질문의 답을 추론해서 채우고, 전체 추론 결과 + 추천을
한 번에 제시해 확인만 받는다. 추론 힌트가 부족한 차원만 Q 순서대로 묻는다.

상세는 `spring-init/references/decision-tree.md` 참조.



### In scope
- `start.spring.io` 기반 신규 프로젝트 생성
- Gradle Kotlin DSL 설정과 의존성 조합
- 패키지 구조 (Layered / Hexagonal / Clean 선택)
- 초기 `application.yml` (환경별 분리)
- Controller–Service–Repository 스캐폴드
- 기본 테스트 구조 (슬라이스 + TestContainers)

### Out of scope
- 기존 프로젝트 마이그레이션 (필요 시 별도 `spring-migrate` 스킬)
- 프로덕션 배포 (Docker, K8s, CI/CD)
- 프론트엔드 통합
- 성능 튜닝, GraalVM native image

## C. 기술 스택

- **언어**: Java 21 (LTS)
- **빌드**: Gradle + Kotlin DSL
- **Boot 버전**: **동적 조회** (하드코딩 금지)
- **테스트**: JUnit 5 + AssertJ + Mockito + TestContainers
- **관찰**: Spring Boot Actuator + Micrometer
- **로깅**: SLF4J + Logback

## D. 동적 버전 처리 전략 (핵심 차별점)

### 원칙
**스킬 안에서 Spring Boot 버전을 절대 하드코딩하지 않는다.**
"3.5.3" 같은 숫자가 스킬 문서나 코드에 박히는 순간, 이 스킬은 수명이
시작된다. 모든 버전은 런타임에 조회해야 한다.

### 구현
1. **메타데이터 조회**: `curl https://start.spring.io/metadata/client`
2. **프로젝트 생성**: `curl https://start.spring.io/starter.zip` POST
3. **스크립트로 추상화**: `spring-init/scripts/fetch-latest-versions.sh`가
   JSON 반환 → SKILL.md 워크플로우가 이 값만 참조
4. **실패 처리**: API 접근 불가 시 사용자에게 알리고 중단 (임의 fallback 금지)

이게 이번 스킬 세트의 존재 이유다. Boot 5.0이 나와도 스킬 수정 없이 자동 대응.

## E. 토비 스프링 철학 반영 방식

공용 스킬 `spring-principles`의 references/에 원칙 문서, templates/에
Before/After 코드 페어를 둔다. 다른 스킬들은 "코드 작성 후
`spring-principles` 체크리스트로 자가 검증"이라고 참조한다.

### 반영할 원칙

1. **DI와 객체 관계**
   - 필드 주입 금지, 생성자 주입 + `final` 필드
   - Lombok `@RequiredArgsConstructor` 또는 명시 생성자
2. **관심사 분리**
   - Controller는 HTTP ↔ DTO 변환만
   - Service는 오케스트레이션
   - Repository는 영속성
   - **DTO와 Entity는 반드시 분리**
3. **테스트 용이성 = 설계 기준**
   - 필요 시 인터페이스 분리
   - 설정과 객체 생성 분리 (`@Bean`은 `@Configuration`에서만)
4. **템플릿/전략 패턴**
   - 반복 try-catch-finally는 템플릿 메서드로
5. **Rich domain model**
   - 비즈니스 규칙은 Entity/VO 내부에
   - Anemic domain 회피
6. **Value Object**
   - 원시 타입 집착(primitive obsession) 회피
   - 도메인 개념은 VO로 추출
7. **의사결정 투명성**
   - 설계 선택은 근거와 함께 제시 (아키텍처 결정 트리의 점수,
     영속성 선택의 trade-off, 인증 방식의 보안 맥락 등)
   - 모델이 혼자 결정하지 않고 사용자가 최종 승인
   - 토비 책의 일관된 질문 "왜 이 설계를 선택하는가"를 구조화한 것

### templates/ 파일 구조 (각 파일)
- Before (안티패턴 코드)
- After (권장 코드)
- 왜 (짧은 설명, 2~3 문장)
- 관련 원칙 링크

---

## 다음 문서

이 문서는 플랜의 **설계 부분(A–E)**이다.
구현 부분(F–J)은 `PLAN-implementation.md` 참조.

- F. SKILL.md 본문 설계 (각 스킬의 프론트매터 + 워크플로우)
- G. references/ 파일별 내용 개요
- H. scripts/ 전문 (3개 스크립트 실제 코드)
- I. 테스트 케이스 & 평가 체크리스트
- J. Claude Code 배포 및 세션 시작 프롬프트
