---
name: spring-principles
description: Use whenever writing, reviewing, or refactoring Java/Spring
  code. This skill encodes design principles from 토비의 스프링 - constructor
  injection, DTO-entity separation, testability, rich domain, and anti-pattern
  avoidance. All other spring-* skills reference this for their
  self-verification checklist. Always consult this before declaring Spring
  code "done".
---

# Spring Principles

Spring/Java 코드를 작성·리뷰·리팩터링할 때 적용할 설계 원칙 모음.
다른 모든 `spring-*` 스킬은 완료 직전에 이 스킬의 체크리스트로 자가 검증한다.

## 절대 원칙

1. **필드 주입 금지** — 생성자 주입 + `final` 필드. Lombok `@RequiredArgsConstructor` 또는 명시 생성자.
2. **Controller는 Entity를 직접 반환·수신하지 않는다** — DTO 매핑 필수.
3. **Anemic domain 회피** — 비즈니스 규칙은 Entity/VO 내부에 둔다.

## 자가 검증 체크리스트

Spring 코드 완성 직전 아래 항목을 전부 확인한다. 위반 항목은 `templates/` 의 Before/After 가이드를 적용해 수정한다.

### DI & 의존성

- [ ] `@Autowired` 필드 주입이 없음
- [ ] 주입 받는 모든 필드가 `private final`
- [ ] 생성자가 하나면 `@RequiredArgsConstructor`, 여럿이면 명시 생성자 + `@Bean`

### 계층 분리

- [ ] Controller가 Entity를 직접 반환하지 않음 (DTO 매핑)
- [ ] Controller가 Repository를 직접 호출하지 않음
- [ ] Service 계층에 `@Transactional` 이 위치함
- [ ] `@Transactional(readOnly = true)` 를 조회 메서드에 적용했는가

### Domain

- [ ] 비즈니스 규칙(검증, 상태 전이)이 Service가 아닌 Entity/VO 내부에 있음
- [ ] Primitive Obsession이 있는 값(금액·이메일·주소 등)은 VO로 추출했는가

### 테스트 용이성

- [ ] `new`로 직접 생성 가능한 클래스 (불필요한 정적 의존 없음)
- [ ] `@Bean`은 `@Configuration` 에만 있음

## 사용법

다른 스프링 스킬(spring-init, spring-web, spring-persistence 등)에서 코드를 작성하고 나면
이 SKILL.md를 읽고 체크리스트를 실행한다. 위반 항목이 발견되면:
1. `templates/<해당-패턴>.md` 의 `## Before` → `## After` 변환을 적용한다.
2. 변환 이유를 `## 왜` 섹션으로 사용자에게 설명한다.

## references/ 목록

| 파일 | 설명 |
|---|---|
| `di.md` | 생성자 주입 원칙, 순환 참조 탐지 |
| `separation-of-concerns.md` | Controller/Service/Repository 각 책임, `@Transactional` 경계 |
| `testability.md` | 테스트하기 쉬운 설계 기준 |
| `rich-domain.md` | Entity에 행위 부여, VO 도입 |
| `anti-patterns.md` | 흔한 안티패턴 목록 |

## templates/ 목록

| 파일 | 변환 |
|---|---|
| `constructor-injection.md` | 필드 주입 → 생성자 주입 |
| `dto-entity-separation.md` | Entity 직접 반환 → DTO 매핑 |
| `rich-domain.md` | Anemic Entity + Service 로직 → Entity 메서드 |
| `template-method-pattern.md` | 반복 try-catch → 템플릿 메서드 |
| `value-object.md` | Primitive 타입 → VO |
