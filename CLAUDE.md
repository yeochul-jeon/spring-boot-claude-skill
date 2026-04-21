# spring-claude-skills

Spring Boot용 Claude Code Skill 세트를 만드는 프로젝트.

## 작업 전 필수 참조

모든 작업은 다음 두 플랜 문서를 먼저 읽고 시작한다:
- `./PLAN.md` (설계 A-E)
- `./PLAN-implementation.md` (구현 F-J)

## 절대 규칙

1. **Spring Boot 버전을 기억에 의존해 적지 않는다.**
   반드시 `skills/spring-init/scripts/fetch-latest-versions.sh` 로 조회한
   값만 사용한다. "3.5.3" 같은 구체적 버전 숫자가 소스·문서에 박히면
   즉시 에러로 간주.

2. **아키텍처 스타일을 가정하지 않는다.**
   `skills/spring-init/references/decision-tree.md` 의 결정 트리를 통해
   추천 → 사용자 승인 → 진행. 동점 시 Layered > Hexagonal > Clean.

3. **각 스킬 완성 시 `tests/cases.md` 해당 케이스를 실행해 검증.**
   특히 케이스 1(버전 하드코딩 방지)은 리그레션 감시용으로 자주 실행.

4. **코드 작성 시 `skills/spring-principles/` 체크리스트로 자가 검증.**
   필드 주입 금지, DTO-Entity 분리, Rich domain, 생성자 주입 등.

## 기술 스택

- Java 21 (LTS)
- Gradle + Kotlin DSL
- Spring Boot (버전은 런타임 조회)
- JUnit 5 + AssertJ + Mockito + TestContainers
- MySQL (기본 권장 또는 PostgreSQL)

## 구현 순서

각 스킬 완성 시점에 멈추고 사용자 확인을 받는다.

1. `spring-init` (entry point, 결정 트리 포함)
2. `spring-principles` (다른 스킬들이 참조)
3. `spring-web`
4. `spring-persistence` (JPA/MyBatis 둘 다)
5. `spring-security`
6. `spring-testing`

## skill-creator 사용

스킬 생성 시 `skill-creator` 스킬을 사용한다. 각 스킬별로:
1. SKILL.md 작성 (PLAN-implementation.md F 섹션 참조)
2. references/ 파일들 작성 (G 섹션 참조)
3. scripts/ 작성 (H 섹션, `spring-init` 만 해당)
4. tests/cases.md 의 해당 테스트로 검증
5. 통과 시 Git commit → 다음 스킬
